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

proc dump_sector(fs : Stream, sector_offset : uint32) =
    createParser(d88_sector_header):
        u8: cylinder
        u8: head
        u8: sector_id
        u8: sector_size
        lu16: sectors_per_track
        u8: density
        u8: is_deleted
        u8: fdc_status
        u8: reserved[5]
        lu16: sector_byte_length

    fs.setPosition(int(sector_offset))
    var sector_data = d88_sector_header.get(fs)
    echo fmt"Cylinder {sector_data.cylinder} Head {sector_data.head} Sector {sector_data.sector_id}"
    echo fmt"Sector size {sector_data.sector_size}"
    echo fmt"Sectors per track {sector_data.sectors_per_track}"
    echo fmt"Sector density {sector_data.density}"
    echo fmt"Is deleted? {sector_data.is_deleted != 0x00}"
    echo fmt"FDC status {sector_data.fdc_status}"
    echo fmt"Reserved sector data = {sector_data.reserved}"
    echo fmt"Sector length in bytes {sector_data.sector_byte_length}"

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

        # remember this for later
        var trackTablePosition = fs.getPosition()

        # read some lu32s off
        var first_track_offset : uint32 = 0
        fs.read(first_track_offset)
        echo fmt"First track offset = {first_track_offset}"

        var expected_tracks : uint16 = 164
        if first_track_offset == 688:
            echo "\t164-track image"
        elif first_track_offset == 672:
            echo "\t160-track image"
            expected_tracks = 160
        else:
            echo "\tFirst track offset looks bad (should be 688 or 672); image may be hosed"

        # Now we can read the entire sector table
        createParser(d88_track_pointer_table, expected_length: uint16):
            lu32: tracks[expected_length]

        # Rewind first so we're in the right spot
        fs.setPosition(trackTablePosition)
        var table = d88_track_pointer_table.get(fs, expected_tracks)
        for i in 0 ..< len(table.tracks):
            if table.tracks[i] != 0:
                # Dump the head sector of each track.
                dump_sector(fs, table.tracks[i])

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
