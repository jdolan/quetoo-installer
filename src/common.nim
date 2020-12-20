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

  var
    pos = 0
    total = 0

  for node in bucket:
    if tag(node) == "Contents" and transform(node.child("Key").innerText) != "":
      total += 1

  for node in bucket:
    if tag(node) == "Contents":
      let key = node.child("Key").innerText
      let path = transform(key)
      if path != "":
        pos += 1
        if shouldUpdate(path, node.child("Size").innerText.parseBiggestInt, node.child("ETag").innerText[1..^2]):
          status(path, pos / total)
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

var
  dir = "."
  outOS = hostOS
  outCPU = hostCPU
  triple = ""
  bin = true
  data = true
  newInstall* = true

proc init*() =
  var check = ""

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
            outOS = val
          of "cpu", "c":
            outCPU = val
      of cmdEnd:
        assert(false)

  case outOS:
    of "windows":
      check = "bin"
      case outCPU:
        of "i386":
          triple = "i686-pc-windows"
        of "amd64":
          triple = "x86_64-pc-windows"
    of "linux":
      check = "bin"
      case outCPU:
        of "amd64":
          triple = "x86_64-pc-linux"
    of "macosx":
      check = "Quetoo.app"
      case outCPU:
        of "amd64":
          triple = "x86_64-apple-darwin"

  if triple == "":
    die("Unknown host: " & outOS & "/" & outCPU)

  if dirExists(dir & "/" & check):
    newInstall = false

proc install*(pDie: proc(s: string), mainstatus: proc(s: string), pStatus: proc(s: string, progress: float)) =
  die = pDie
  status = pStatus

  try:
    createDir(dir)
    setCurrentDir(dir)

    if bin:
      mainstatus((if newInstall: "Installing" else: "Updating") & " Quetoo binaries (1/2)")
      download("https://quetoo.s3.amazonaws.com/", (path) => (if path.startsWith(triple): path[len(triple)+1..^1] else: ""))

    if data:
      mainstatus((if newInstall: "Installing" else: "Updating") & " Quetoo data (2/2)")
      if outOS != "macosx":
        download("https://quetoo-data.s3.amazonaws.com/", (path) => "share/" & path)
      else:
        download("https://quetoo-data.s3.amazonaws.com/", (path) => "Quetoo.app/Contents/Resources/" & path)

    if outOS == "linux":
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
