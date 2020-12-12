# Package

version       = "0.0.0"
author        = "Gibson"
description   = "Quetoo installer"
license       = "ISC"
srcDir        = "src"
bin           = @["quetoo_installer_cli", "quetoo_installer"]


# Dependencies

requires "nim >= 1.4.2, nigui#HEAD"
