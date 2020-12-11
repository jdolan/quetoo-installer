import common

proc die(s: string) =
  echo("\n", s)
  quit(1)

proc mainstatus(s: string) =
  echo("\n>>> ", s, "\n")

proc status(s: string) =
  echo(s)

install(die, mainstatus, status)
