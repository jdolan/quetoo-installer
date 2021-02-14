import httpclient, xmltree, xmlparser, sugar, strutils, os, md5, uri, parseopt

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

proc download(url: string, transform: (string) -> string): seq[string] =
  ## Downloads the Amazon S3 bucket at `url`.
  ## `transform()` is called for each file in the bucket, it can return the local output path or "" to prevent it being downloaded.
  ##
  ## Returns a seq[string] containing all files that were downloaded/verified.

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

  var files: seq[string]
  var pos = 0
  for node in contents:
    let key = node.child("Key").innerText
    let path = transform(key)
    files.add(path)
    pos += 1
    if shouldUpdate(path, node.child("Size").innerText.parseBiggestInt, node.child("ETag").innerText[1..^2]):
      status(path, pos / len(contents))
      createDir(splitFile(path)[0])
      try:
        writeFile(path, client.getContent(url & encodeUrl(key)))
      except ProtocolError: # Attempt retry in case of "Connection was closed before full request has been made"
        client = newHttpClient()
        writeFile(path, client.getContent(url & encodeUrl(key)))

  return files

type
  InstallerOptions* = object
    dir*, os*, cpu*, forceTriple*: string
    installBin*, installData*, purge*: bool

proc newInstallerOptions*(): InstallerOptions =
  InstallerOptions(
    dir: ".",
    os: hostOS,
    cpu: hostCPU,
    forceTriple: "", # for java compat (--build option)
    installBin: true,
    installData: true,
    purge: true,
  )

proc isNewInstall*(opts: InstallerOptions): bool =
  var check: string
  case opts.os:
    of "windows", "linux":
      check = "bin"
    of "macosx":
      check = "Quetoo.app"
    else:
      return true
  return not dirExists(opts.dir & "/" & check)

let help = """
Quetoo Installer

Usage: """ & paramStr(0) & """ [options] [<dir>]

Options:
  -h      --help       Show this message.
  -b      --bin        Only update binaries.
  -d      --data       Only update data.
  -k      --keep       Don't delete unrecognised/outdated files.
  -o<os>  --os <os>    Override OS detection (windows, mingw, linux, macosx)
  -c<cpu> --cpu <cpu>  Override OS detection (i386, amd64)
"""

proc install*(opts: var InstallerOptions, pDie: proc(s: string), mainstatus: proc(s: string), pStatus: proc(s: string, progress: float)) =
  die = pDie
  status = pStatus

  for kind, key, val in getopt(commandLineParams(), {'h', 'b', 'd', 'k'}, @["help", "bin", "data", "keep"]):
    case kind:
      of cmdArgument:
        opts.dir = key
      of cmdLongOption, cmdShortOption:
        case key:
          of "help", "h", "?":
            echo(help)
            quit(0)
          of "bin", "b":
            opts.installData = false
          of "data", "d":
            opts.installBin = false
          of "keep", "k":
            opts.purge = false
          of "os", "o":
            opts.os = val
          of "cpu", "c":
            opts.cpu = val
          of "build":
            opts.forceTriple = val
          else:
            echo "warning: unrecognised argument " & key
      of cmdEnd:
        assert(false)

  var triple = opts.forceTriple
  if triple == "":
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
    return

  try:
    createDir(opts.dir)
    setCurrentDir(opts.dir)

    var files: seq[string]

    var task, nTasks: int
    for opt in [opts.installBin, opts.installData, opts.purge]:
      if opt:
        nTasks += 1
    if opts.os == "linux":
      nTasks += 1
    let tasks = $nTasks

    if opts.installBin:
      task += 1
      mainstatus((if isNewInstall(opts): "Installing" else: "Updating") & " Quetoo binaries (" & $task & "/" & tasks & ")")
      files = download("https://quetoo.s3.amazonaws.com/", (path) => (if path.startsWith(triple): path[len(triple)+1..^1] else: ""))

    if opts.installData:
      task += 1
      mainstatus((if isNewInstall(opts): "Installing" else: "Updating") & " Quetoo data (" & $task & "/" & tasks & ")")
      if opts.os != "macosx":
        files &= download("https://quetoo-data.s3.amazonaws.com/", (path) => "share/" & path)
      else:
        files &= download("https://quetoo-data.s3.amazonaws.com/", (path) => "Quetoo.app/Contents/Resources/" & path)

    if opts.purge:
      task += 1
      mainstatus("Removing outdated files (" & $task & "/" & tasks & ")")
      status("Checking...", 0)
      var paths: seq[string]
      case opts.os:
        of "windows", "mingw", "linux":
          if opts.installBin:
            paths &= @["bin", "lib"]
          if opts.installData:
            paths &= @["share"]
        of "macosx":
          if opts.installBin:
            paths &= @["Update.app"]
            if opts.installData:
              paths &= @["Quetoo.app"] # XXX: macos stores binaries and data in the app bundle so we don't purge it unless both were installed

      for p in paths:
        for f in walkDirRec(p):
          if f.replace(DirSep, '/') notin files:
            removeFile(f)

    if opts.os == "linux":
      task += 1
      mainstatus("Making binaries executable (" & $task & "/" & tasks & ")")
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
