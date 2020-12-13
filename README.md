# quetoo-installer

This utility installs and updates [Quetoo](https://github.com/jdolan/quetoo).

## Building

Install the latest version of [Nim](https://nim-lang.org). To build the graphical installer on Unix platforms, [GTK+ 3](https://gtk.org) is required. Once dependencies are installed, run

    nimble build

For a release build (runs much faster), pass `-d:release`. To cross-compile for Windows using [mingw-w64](http://mingw-w64.org), pass `-d:mingw`.
