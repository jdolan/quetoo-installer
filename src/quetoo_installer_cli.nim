import common, os, parseopt

proc die(s: string) =
  echo("\n", s)
  quit(1)

proc mainstatus(s: string) =
  echo("\n>>> ", s, "\n")

proc status(s: string, progress: float) =
  echo(s)

let help = """
Quetoo Installer

Usage: """ & paramStr(0) & """ [options] [<dir>]

Options:
  -h      --help       Show this message.
  -b      --bin        Only update binaries.
  -d      --data       Only update data.
  -k      --keep       Don't delete unrecognised/outdated files.
  -o<os>  --os <os>    Override OS detection (windows, mingw, linux, macosx)
  -c<cpu> --cpu <cpu>  Override OS detection (i386, amd64)
"""

var opts = newInstallerOptions()

for kind, key, val in getopt(commandLineParams(), {'h', 'b', 'd', 'k'}, @["help", "bin", "data", "keep"]):
  case kind:
    of cmdArgument:
      opts.dir = key
    of cmdLongOption, cmdShortOption:
      case key:
        of "help", "h", "?":
          echo(help)
          quit(0)
        of "bin", "b":
          opts.installData = false
        of "data", "d":
          opts.installBin = false
        of "keep", "k":
          opts.purge = false
        of "os", "o":
          opts.os = val
        of "cpu", "c":
          opts.cpu = val
        of "build":
          opts.forceTriple = val
        else:
          echo "warning: unrecognised argument " & key
    of cmdEnd:
      assert(false)

install(opts, die, mainstatus, status)
