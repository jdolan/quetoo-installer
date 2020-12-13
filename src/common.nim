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

proc download(url: string, transform: (string) -> string) =
  ## Downloads the Amazon S3 bucket at `url`.
  ## `transform()` is called for each file in the bucket, it can return the local output path or "" to prevent it being downloaded.

  let client = newHttpClient()

  status("Loading file list...", 0)
  let bucket = parseXml(client.get(url).bodyStream)

  var pos = 0
  for node in bucket:
    pos += 1
    if tag(node) == "Contents":
      let key = node.child("Key").innerText
      let path = transform(key)
      if path != "":
        if shouldUpdate(path, node.child("Size").innerText.parseBiggestInt, node.child("ETag").innerText[1..^2]):
          status(path, pos / bucket.len)
          createDir(splitFile(path)[0])
          writeFile(path, client.getContent(url & encodeUrl(key)))

let help = """
Quetoo Installer

Usage: """ & paramStr(0) & """ [options] [<dir>]

Options:
  -h      --help       Show this message.
  -b      --bin        Only update binaries.
  -d      --data       Only update data.
  -o<os>  --os <os>    Override OS detection (windows, linux, macosx)
  -c<cpu> --cpu <cpu>  Override OS detection (i386, amd64)
"""

proc install*(pDie: proc(s: string), mainstatus: proc(s: string), pStatus: proc(s: string, progress: float)) =
  die = pDie
  status = pStatus

  var
    dir = "."
    os = hostOS
    cpu = hostCPU
    bin = true
    data = true

  for kind, key, val in getopt(commandLineParams(), {'h', 'b', 'd'}, @["help", "bin", "data"]):
    case kind:
      of cmdArgument:
        dir = key
      of cmdLongOption, cmdShortOption:
        case key:
          of "help", "h", "?":
            echo(help)
            quit(0)
          of "bin", "b":
            data = false
          of "data", "d":
            bin = false
          of "os", "o":
            os = val
          of "cpu", "c":
            cpu = val
      of cmdEnd:
        assert(false)

  var triple: string
  case os:
    of "windows":
      case cpu:
        of "i386":
          triple = "i686-pc-windows"
        of "amd64":
          triple = "x86_64-pc-windows"
    of "linux":
      case cpu:
        of "amd64":
          triple = "x86_64-pc-linux"
    of "macosx":
      case cpu:
        of "amd64":
          triple = "x86_64-apple-darwin"

  if triple == "":
    die("Unknown host: " & os & "/" & cpu)

  try:
    createDir(dir)
    setCurrentDir(dir)

    if bin:
      mainstatus("Updating Quetoo binaries (1/2)")
      download("https://quetoo.s3.amazonaws.com/", (path) => (if path.startsWith(triple): path[len(triple)+1..^1] else: ""))

    if data:
      mainstatus("Updating Quetoo data (2/2)")
      if os != "macosx":
        download("https://quetoo-data.s3.amazonaws.com/", (path) => "share/" & path)
      else:
        download("https://quetoo-data.s3.amazonaws.com/", (path) => "Quetoo.app/Contents/Resources/" & path)

    if os == "linux":
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
