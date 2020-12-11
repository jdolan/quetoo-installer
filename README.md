# quetoo-installer

This utility installs and updates [Quetoo](https://github.com/jdolan/quetoo).

## Building

Install the latest version of [Nim](https://nim-lang.org), then

    nimble build

For a release build (runs much faster), pass `-d:release`. To cross-compile for Windows using [MinGW](http://mingw-w64.org), pass `-d:mingw`.
