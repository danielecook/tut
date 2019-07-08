# Package

version       = "0.0.1"
author        = "Daniel E. Cook"
description   = "Table Utilities"
license       = "MIT"

# Dependencies

requires "argparse >= 0.7.1", "colorize"

bin = @["tut"]
skipDirs = @["test"]

task test, "run tests":
  exec "nim c --lineDir:on --debuginfo -r tests/all"