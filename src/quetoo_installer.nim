import common, os, parsecfg, strutils, nigui, nigui/msgbox

var opts = newInstallerOptions()
let cfgPath = getConfigDir() & "quetoo-installer/config.cfg"
try:
  let cfg = loadConfig(cfgPath)
  opts.dir = cfg.getSectionValue("", "dir", opts.dir)
  opts.os = cfg.getSectionValue("", "os", opts.os)
  opts.cpu = cfg.getSectionValue("", "cpu", opts.cpu)
  opts.installBin = cfg.getSectionValue("", "installBin", $opts.installBin).parseBool
  opts.installData = cfg.getSectionValue("", "installData", $opts.installBin).parseBool
  opts.purge = cfg.getSectionValue("", "purge", $opts.purge).parseBool
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

var purgeCheckbox = newCheckbox("Purge old files")
purgeCheckbox.checked = opts.purge
optionContainer.add(purgeCheckbox)

var osComboBox = newComboBox(@["windows", "mingw", "linux", "macosx"])
osComboBox.value = opts.os
optionContainer.add(osComboBox)

var cpuComboBox = newComboBox(@["i386", "amd64"])
cpuComboBox.value = opts.cpu
optionContainer.add(cpuComboBox)

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
  opts.os = osComboBox.value
  opts.cpu = cpuComboBox.value
  opts.installBin = binCheckbox.checked
  opts.installData = dataCheckbox.checked
  opts.purge = purgeCheckbox.checked

  var cfg = newConfig()
  cfg.setSectionKey("", "dir", opts.dir)
  cfg.setSectionKey("", "os", opts.os)
  cfg.setSectionKey("", "cpu", opts.cpu)
  cfg.setSectionKey("", "installBin", $opts.installBin)
  cfg.setSectionKey("", "installData", $opts.installData)
  cfg.setSectionKey("", "purge", $opts.purge)
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
