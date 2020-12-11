import httpclient, xmltree, xmlparser, sugar, strutils, os, md5, uri

var
  die: proc(s: string)
  status: proc(s: string)

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

  status("Loading file list...")
  var bucket = parseXml(client.get(url).bodyStream)

  for node in bucket:
    if tag(node) == "Contents":
      let key = node.child("Key").innerText
      let path = transform(key)
      if path != "":
        if shouldUpdate(path, node.child("Size").innerText.parseBiggestInt, node.child("ETag").innerText[1..^2]):
          status(path)
          createDir(splitFile(path)[0])
          writeFile(path, client.getContent(url & encodeUrl(key)))

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
