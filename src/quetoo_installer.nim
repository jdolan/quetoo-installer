import common, nigui, nigui/msgbox

var
  win: Window
  box: LayoutContainer
  button: Button
  label1, label2: Label
  pbar: ProgressBar
  thread: Thread[void]
  queue: int

proc die(s: string) =
  {.gcsafe.}:
    inc queue
    app.queueMain(proc() =
      win.msgBox(s, "Error", "Close")
      app.quit()
      dec queue)

proc mainstatus(s: string) =
  {.gcsafe.}:
    inc queue
    app.queueMain(proc() =
      label1.text = s
      dec queue)

proc status(s: string, progress: float) =
  {.gcsafe.}:
    inc queue
    app.queueMain(proc() =
      label2.text = s
      pbar.value = progress
      dec queue)

init()

app.init()

win = newWindow("Quetoo Installer")
win.width = 400.scaleToDpi
win.height = 125.scaleToDpi

box = newLayoutContainer(Layout_Vertical)
box.padding = 10
win.add(box)

button = newButton(if newInstall: "Install" else: "Update")
box.add(button)

proc start() =
  {.gcsafe.}:
    install(die, mainstatus, status)
    while queue > 0:
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
