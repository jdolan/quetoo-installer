import common, nigui, nigui/msgbox

var
  win: Window
  box: LayoutContainer
  button: Button
  label1, label2: Label
  pbar: ProgressBar
  thread: Thread[void]

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

var opts = newInstallerOptions()

app.init()

win = newWindow("Quetoo Installer")
win.width = 400.scaleToDpi
win.height = 125.scaleToDpi

box = newLayoutContainer(Layout_Vertical)
box.padding = 10
win.add(box)

button = newButton(if isNewInstall(opts): "Install" else: "Update")
box.add(button)

proc start() =
  {.gcsafe.}:
    install(opts, die, mainstatus, status)
    while app.queued() > 0:
      discard

button.onClick = proc(event: ClickEvent) =
  box.remove(button)

  label1 = newLabel("Initialising")
  box.add(label1)

  pbar = newProgressBar()
  box.add(pbar)

  label2 = newLabel("")
  box.add(label2)

  createThread(thread, start)

win.show()
app.run()
