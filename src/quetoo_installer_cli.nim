import common

proc die(s: string) =
  echo("\n", s)
  quit(1)

proc mainstatus(s: string) =
  echo("\n>>> ", s, "\n")

proc status(s: string, progress: float) =
  echo(s)

var opts = newInstallerOptions()
install(opts, die, mainstatus, status)
