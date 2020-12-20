import common, nigui, nigui/msgbox, threadpool

var
  win: Window
  box: LayoutContainer
  button: Button
  label1, label2: Label
  pbar: ProgressBar

proc die(s: string) =
  {.gcsafe.}:
    app.queueMain(proc() =
      win.msgBox(s, "Error", "Close")
      app.quit())

proc mainstatus(s: string) =
  {.gcsafe.}:
    app.queueMain(proc() =
      label1.text = s)

proc status(s: string, progress: float) =
  {.gcsafe.}:
    app.queueMain(proc() =
      label2.text = s
      pbar.value = progress)

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

button.onClick = proc(event: ClickEvent) =
  box.remove(button)

  label1 = newLabel("Initialising")
  box.add(label1)

  pbar = newProgressBar()
  box.add(pbar)

  label2 = newLabel("")
  box.add(label2)

  spawn start()

win.show()
app.run()
