import common, nigui, nigui/msgbox

var opts = newInstallerOptions()

app.init()

var win = newWindow("Quetoo Installer")
win.width = 400.scaleToDpi
win.height = 125.scaleToDpi

var container = newLayoutContainer(Layout_Vertical)
container.padding = 10
win.add(container)

var button = newButton(if isNewInstall(opts): "Install" else: "Update")
container.add(button)

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
  container.remove(button)

  label1 = newLabel("Initialising")
  container.add(label1)

  pbar = newProgressBar()
  container.add(pbar)

  label2 = newLabel("")
  container.add(label2)

  createThread(thread, start)

win.show()
app.run()
