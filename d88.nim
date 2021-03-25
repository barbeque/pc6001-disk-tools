import os
import binaryparse, streams
import strformat
import parseopt

proc dump(filename : string) =
    createParser(d88_header):
        s: disk_name[17]
        8: reserved[9]
        u8: write_protected
        u8: disk_type
        u32: disk_size

    echo fmt"Reading d88 = '{filename}'"
    var fs = newFileStream(filename, fmRead)
    defer: fs.close()
    if not fs.isNil:
        var data = d88_header.get(fs)
        echo fmt"Disk name = '{data.disk_name}'"
        echo fmt"Write protected? = '{data.write_protected}'"
        echo fmt"Disk type = '{data.disk_type}'"
        echo fmt"Disk size = '{data.disk_size}'"

proc usage() =
    echo "Usage: d88 [command] filename"
    echo "Commands: --help, --dump"

var filename: string
type Mode = enum
    d88Nil, d88Dump
var mode : Mode = d88Nil

for kind, key, val in getopt(commandLineParams()):
    case kind
    of cmdArgument:
        filename = key
    of cmdLongOption, cmdShortOption:
        case key
        of "help", "h": usage()
        of "dump", "d": mode = d88Dump
    of cmdEnd:
        assert(false)

if filename == "":
    usage()
else:
    # begin parsing
    case mode
    of d88Dump: dump(filename)
    else: usage()
