# Package

version       = "0.0.0"
author        = "Gibson"
description   = "Quetoo installer"
license       = "ISC"
srcDir        = "src"
bin           = @["quetoo_installer_cli", "quetoo_installer"]


# Dependencies

requires "nim >= 1.4.2, nigui >= 0.2.5"

task resource, "Generates Windows resource files":
  exec "i686-w64-mingw32-windres src/windows/resource.rc src/windows/i386.o"
  exec "x86_64-w64-mingw32-windres src/windows/resource.rc src/windows/amd64.o"
