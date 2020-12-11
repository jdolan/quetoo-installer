import httpclient, xmltree, xmlparser

var
  die: proc(s: string)
  status: proc(s: string)

proc download(url: string) =
  var client = newHttpClient()

  status("Loading file list...")
  var bucket = parseXml(client.get(url).bodyStream)

  for node in bucket:
    if tag(node) == "Contents":
      status(node.child("Key").innerText)

proc install*(pDie: proc(s: string), mainstatus: proc(s: string), pStatus: proc(s: string)) =
  die = pDie
  status = pStatus

  try:
    mainstatus("Installing")
    download("https://quetoo.s3.amazonaws.com/")
  except:
    die(getCurrentExceptionMsg())
