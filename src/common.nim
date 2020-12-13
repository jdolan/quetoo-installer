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

  for node in bucket:
    if tag(node) == "Contents":
      let key = node.child("Key").innerText
      let path = transform(key)
      if path != "":
        if shouldUpdate(path, node.child("Size").innerText.parseBiggestInt, node.child("ETag").innerText[1..^2]):
          status(path, 0.5)
          createDir(splitFile(path)[0])
          writeFile(path, client.getContent(url & encodeUrl(key)))

let help = """
Quetoo Installer

Usage: """ & paramStr(0) & """ [options] [<dir>]

Options:
  -h      --help       Show this message.
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

  for kind, key, val in getopt(commandLineParams(), {'h'}, @["help"]):
    case kind:
      of cmdArgument:
        dir = key
      of cmdLongOption, cmdShortOption:
        case key:
          of "help", "h", "?":
            echo(help)
            quit(0)
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

  try:
    createDir(dir)
    setCurrentDir(dir)
    mainstatus("Updating Quetoo binaries (1/2)")
    download("https://quetoo.s3.amazonaws.com/", (path) => (if path.startsWith(triple): path[len(triple)+1..^1] else: ""))
    mainstatus("Updating Quetoo data (2/2)")
    download("https://quetoo-data.s3.amazonaws.com/", (path) => "share/" & path)
    mainstatus("Done")
    status("", 1)
  except:
    die(getCurrentExceptionMsg())
