import httpclient, xmltree, xmlparser, sugar, strutils

var
  die: proc(s: string)
  status: proc(s: string)

proc download(url: string, transform: (string) -> string) =
  ## Downloads the Amazon S3 bucket at `url`.
  ## `transform()` is called for each file in the bucket, it can return the local output path or "" to prevent it being downloaded.

  var client = newHttpClient()

  status("Loading file list...")
  var bucket = parseXml(client.get(url).bodyStream)

  for node in bucket:
    if tag(node) == "Contents":
      let key = node.child("Key").innerText
      let path = transform(key)
      if path != "":
        status(path)

proc install*(pDie: proc(s: string), mainstatus: proc(s: string), pStatus: proc(s: string)) =
  die = pDie
  status = pStatus

  var triple: string
  case hostOS:
    of "windows":
      case hostCPU:
        of "i386":
          triple = "i686-pc-windows"
        of "amd64":
          triple = "x86_64-pc-windows"
    of "linux":
      case hostCPU:
        of "amd64":
          triple = "x86_64-pc-linux"
    of "macosx":
      case hostCPU:
        of "amd64":
          triple = "x86_64-apple-darwin"

  try:
    mainstatus("Installing")
    download("https://quetoo.s3.amazonaws.com/", (path) => (if path.startsWith(triple): path[len(triple)+1..^1] else: ""))
  except:
    die(getCurrentExceptionMsg())
