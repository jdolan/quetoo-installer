import common, os, parsecfg, strutils, nigui, nigui/msgbox

var opts = newInstallerOptions()
let cfgPath = getConfigDir() & "quetoo-installer/config.cfg"
try:
  let cfg = loadConfig(cfgPath)
  opts.dir = cfg.getSectionValue("", "dir", opts.dir)
  opts.installBin = cfg.getSectionValue("", "installBin", $opts.installBin).parseBool
  opts.installData = cfg.getSectionValue("", "installData", $opts.installBin).parseBool
except IOError:
  discard
let verb = if isNewInstall(opts): "Install" else: "Update"

app.init()

var win = newWindow("Quetoo Installer")
win.width = 600.scaleToDpi
win.height = 400.scaleToDpi

var container = newLayoutContainer(Layout_Vertical)
container.padding = 10
win.add(container)

var button = newButton(verb)
container.add(button)

var optionContainer = newLayoutContainer(Layout_Vertical)
var optionFrame = newFrame("Options")
optionContainer.frame = optionFrame
container.add(optionContainer)

var dirButton = newButton("Select directory")
dirButton.onClick = proc(event: ClickEvent) =
  var dialog = SelectDirectoryDialog()
  dialog.title = "Select install directory"
  dialog.startDirectory = opts.dir
  dialog.run()
  if dialog.selectedDirectory != "":
    opts.dir = dialog.selectedDirectory
optionContainer.add(dirButton)

var binCheckbox = newCheckbox(verb & " binaries")
binCheckbox.checked = opts.installBin
optionContainer.add(binCheckbox)

var dataCheckbox = newCheckbox(verb & " data")
dataCheckbox.checked = opts.installData
optionContainer.add(dataCheckbox)

var
  label1, label2: Label
  pbar: ProgressBar

proc die(s: string) =
  {.gcsafe.}:
    app.queueMain(proc() =
      win.msgBox(s, "Error", "Close")
      app.quit()
    )

proc mainstatus(s: string) =
  {.gcsafe.}:
    app.queueMain(proc() =
      label1.text = s
    )

proc status(s: string, progress: float) =
  {.gcsafe.}:
    app.queueMain(proc() =
      label2.text = s
      pbar.value = progress
    )

proc start() =
  {.gcsafe.}:
    install(opts, die, mainstatus, status)
    while app.queued() > 0:
      discard

var thread: Thread[void]

button.onClick = proc(event: ClickEvent) =
  opts.installBin = binCheckbox.checked
  opts.installData = dataCheckbox.checked

  var cfg = newConfig()
  cfg.setSectionKey("", "dir", $opts.dir)
  cfg.setSectionKey("", "installBin", $opts.installBin)
  cfg.setSectionKey("", "installData", $opts.installData)
  createDir(splitPath(cfgPath)[0])
  writeConfig(cfg, cfgPath)

  container.remove(optionContainer)
  container.remove(button)

  label1 = newLabel("Initialising")
  container.add(label1)

  pbar = newProgressBar()
  container.add(pbar)

  label2 = newLabel("")
  container.add(label2)

  app.processEvents()
  createThread(thread, start)

win.show()
app.run()
