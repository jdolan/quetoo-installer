proc install*(die: proc(s: string), mainstatus: proc(s: string), status: proc(s: string)) =
  mainstatus("Installing")
  status("Test")
  status("Test 2")
  die("Failed")
