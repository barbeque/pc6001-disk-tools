import os
import binaryparse, streams
import strformat
import parseopt
import strutils

proc setRxrHeader(filename: string, verbose: bool) =
    var diskContent = readFile(filename)

    # offset 704 seems to be the magic one
    if diskContent[704] == 'S' and diskContent[705] == 'Y' and diskContent[706] == 'S':
        diskContent[704] = 'R';
        diskContent[705] = 'X';
        diskContent[706] = 'R';

        var outputFilename = "RXR-" & filename
        writeFile(outputFilename, diskContent)

        if verbose:
            echo fmt"Saved modified disk image to '{outputFilename}'."
    else:
        echo fmt"Disk image does not contain the SYS header tag at offset 704. Bailing out."

proc changeMediaType(filename: string, rawMediaType: string, verbose: bool) =
    # parse the media type
    var newMediaType = parseHexInt(rawMediaType)
    var diskContent = readFile(filename)

    if verbose:
        echo fmt"Changing disk type from 0x{toHex(cast[int](diskContent[0x1b]), 4)} to 0x{toHex(newMediaType, 4)}."

    diskContent[0x1b] = cast[char](newMediaType)

    var diskTypePrefix =
        case newMediaType
            of 0x40: "1dd"
            else: rawMediaType

    var output_filename = diskTypePrefix & "-" & filename
    writeFile(output_filename, diskContent)

    if verbose:
        echo fmt"Modified image written to {output_filename}"

proc guess_media_type(media_type : uint8) : string =
    return case media_type:
        of 0x00: "2D"
        of 0x10: "2DD"
        of 0x20: "2HD"
        else: "unknown"

proc dump(filename : string) =
    createParser(d88_header):
        u8: disk_name[17]
        u8: reserved[9]
        u8: write_protected
        u8: disk_type
        lu32: disk_size

    echo fmt"Reading d88 = '{filename}'"
    var fs = newFileStream(filename, fmRead)
    defer: fs.close()
    if not fs.isNil:
        var data = d88_header.get(fs)
        echo fmt"Disk name = '{cast[string](data.disk_name)}'"
        echo fmt"Write protected? = '{data.write_protected == 0x10}'"
        echo fmt"Disk media type = '${toHex(data.disk_type, 2)}' ({guess_media_type(data.disk_type)})"
        echo fmt"Disk size = '{data.disk_size}' bytes"
        echo fmt"Reserved = '{data.reserved}'"

proc usage() =
    echo fmt"Usage: {lastPathPart(paramStr(0))} [command] filename"
    echo "Commands: --help, --dump, --media <new media type>, --rxr"
    echo "Options: --verbose"
    quit(1)

var filename: string
var newDiskType: string
var verbose = false
type Mode = enum
    d88Nil, d88Dump, d88ChangeMediaType, d88SetRxrHeader
var mode : Mode = d88Nil

for kind, key, val in getopt(commandLineParams()):
    case kind
    of cmdArgument:
        # FIXME: this means that i have to put --media AFTER the filename
        if filename == "":
            filename = key
        elif mode == d88ChangeMediaType:
            newDiskType = key
        else:
            usage()
    of cmdLongOption, cmdShortOption:
        case key
        of "help", "h": usage()
        of "dump", "d": mode = d88Dump
        of "media", "m": mode = d88ChangeMediaType
        of "rxr", "r": mode = d88SetRxrHeader
        of "verbose", "v": verbose = true
    of cmdEnd:
        assert(false)

if filename == "":
    usage()
else:
    # begin parsing
    case mode
    of d88Dump: dump(filename)
    of d88ChangeMediaType: changeMediaType(filename, newDiskType, verbose)
    of d88SetRxrHeader: setRxrHeader(filename, verbose)
    else: usage()
