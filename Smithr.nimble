# Package

version       = "0.1.0"
author        = "Brent Gruber"
description   = "A Command Line Interface for creating linux autoinstall isos"
license       = "Apache-2.0"
srcDir        = "src"
bin           = @["Smithr"]


# Dependencies

requires "nim >= 1.6.4"
requires "cligen >= 1.5.23"
requires "tempdir >= 1.0.1"