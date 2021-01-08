import httpclient, xmltree, xmlparser, sugar, strutils, os, md5, uri

when defined(windows):
  when defined(i386):
    {.link: "windows/i386.o".}
  elif defined(amd64):
    {.link: "windows/amd64.o".}

var
  die: proc(s: string)
  status: proc(s: string, progress: float)

proc shouldUpdate(path: string, size: BiggestInt, md5: string): bool =
  if not fileExists(path):
    return true
  elif getFileSize(path) != size:
    return true
  elif getMD5(readFile(path)) != md5:
    return true
  else:
    return false

proc download(url: string, transform: (string) -> string) =
  ## Downloads the Amazon S3 bucket at `url`.
  ## `transform()` is called for each file in the bucket, it can return the local output path or "" to prevent it being downloaded.

  var client = newHttpClient()

  status("Loading file list...", 0)
  var contents: seq[XmlNode]
  var append: string
  while true:
    let bucket = parseXml(client.get(url & append).bodyStream)
    for node in bucket:
      if tag(node) == "Contents" and transform(node.child("Key").innerText) != "":
        contents.add(node)
    if bucket.child("IsTruncated").innerText == "true":
      append = "?marker=" & encodeUrl(contents[^1].child("Key").innerText)
    else:
      break

  status("Checking files...", 0)

  var pos = 0
  for node in contents:
    let key = node.child("Key").innerText
    let path = transform(key)
    pos += 1
    if shouldUpdate(path, node.child("Size").innerText.parseBiggestInt, node.child("ETag").innerText[1..^2]):
      status(path, pos / len(contents))
      createDir(splitFile(path)[0])
      try:
        writeFile(path, client.getContent(url & encodeUrl(key)))
      except ProtocolError: # Attempt retry in case of "Connection was closed before full request has been made"
        client = newHttpClient()
        writeFile(path, client.getContent(url & encodeUrl(key)))

type
  InstallerOptions* = object
    dir*, os*, cpu*: string
    installBin*, installData*: bool

proc newInstallerOptions*(): InstallerOptions =
  InstallerOptions(
    dir: ".",
    os: hostOS,
    cpu: hostCPU,
    installBin: true,
    installData: true,
  )

proc isNewInstall*(opts: InstallerOptions): bool =
  var check: string
  case opts.os:
    of "windows", "linux":
      check = "bin"
    of "macosx":
      check = "Quetoo.app"
  return not dirExists(opts.dir & "/" & check)

proc install*(opts: InstallerOptions, pDie: proc(s: string), mainstatus: proc(s: string), pStatus: proc(s: string, progress: float)) =
  die = pDie
  status = pStatus

  var triple: string
  case opts.os:
    of "windows":
      case opts.cpu:
        of "i386":
          triple = "i686-pc-windows"
        of "amd64":
          triple = "x86_64-pc-windows"
    of "mingw":
      case opts.cpu:
        of "i386":
          triple = "i686-w64-mingw32"
        of "amd64":
          triple = "x86_64-w64-mingw32"
    of "linux":
      case opts.cpu:
        of "amd64":
          triple = "x86_64-pc-linux"
    of "macosx":
      case opts.cpu:
        of "amd64":
          triple = "x86_64-apple-darwin"

  if triple == "":
    die("Unknown host: " & opts.os & "/" & opts.cpu)

  try:
    createDir(opts.dir)
    setCurrentDir(opts.dir)

    if opts.installBin:
      mainstatus((if isNewInstall(opts): "Installing" else: "Updating") & " Quetoo binaries (1/2)")
      download("https://quetoo.s3.amazonaws.com/", (path) => (if path.startsWith(triple): path[len(triple)+1..^1] else: ""))

    if opts.installData:
      mainstatus((if isNewInstall(opts): "Installing" else: "Updating") & " Quetoo data (2/2)")
      if opts.os != "macosx":
        download("https://quetoo-data.s3.amazonaws.com/", (path) => "share/" & path)
      else:
        download("https://quetoo-data.s3.amazonaws.com/", (path) => "Quetoo.app/Contents/Resources/" & path)

    if opts.os == "linux":
      mainstatus("Making binaries executable (3/2)")
      for f in walkFiles("bin/*"):
        let perms = getFilePermissions(f)
        const mapping = {
          fpUserRead: fpUserExec,
          fpGroupRead: fpGroupExec,
          fpOthersRead: fpOthersExec,
        }
        for (k,v) in mapping:
          if k in perms:
            setFilePermissions(f, getFilePermissions(f) + {v})

    mainstatus("Done")
    status("", 1)
  except:
    die(getCurrentExceptionMsg())
