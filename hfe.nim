import os
import streams
import strformat
import parseopt
import strutils
import binaryparse

createParser(hfe):
    s8: sig
    u8: format_rev
    u8: number_tracks
    u8: number_sides
    u8: track_encoding
    lu16: bitrate
    lu16: rpm
    u8: interface_mode
    u8: reserved
    lu16: tracklist_offset
    u8: write_allowed
    u8: single_step
    u8: t0s0_altencoding
    u8: t0s0_encoding
    u8: t0s1_altencoding
    u8: t0s1_encoding

proc dumpHfeHeader(input_filename : string) =
    var fs = newFileStream(input_filename, fmRead)

    if not fs.isNil:
        defer: fs.close()
        # parse with the binary parser
        var parsed = hfe.get(fs)
        echo "Signature: ", parsed.sig
        echo "Format revision ", parsed.format_rev
        echo "# Tracks: ", parsed.number_tracks
        echo "# Sides: ", parsed.number_sides
        echo "Encoding: ", parsed.track_encoding # TODO: Enum
        echo "Bitrate: ", parsed.bitrate
        echo "RPM: ", parsed.rpm
        echo "Interface mode: ", parsed.interface_mode
        echo "Reserved: ", parsed.reserved
        echo "Tracklist offset: ", parsed.tracklist_offset
        echo "Write Allowed?: ", parsed.write_allowed
        echo "Single Step? ", (parsed.single_step != 0)
        echo "Track 0/Side 0 alt. encoding ", parsed.t0s0_altencoding
        echo "Track 0/Side 0 reg. encoding ", parsed.t0s0_encoding
        echo "Track 0/Side 1 alt. encoding ", parsed.t0s1_altencoding
        echo "Track 0/Side 1 reg. encoding ", parsed.t0s1_encoding

# Command line stuff
proc usage() =
    echo fmt"Usage: {lastPathPart(paramStr(0))} [command] filename"
    echo "Commands: --help, --header"
    quit(1)

var filename: string
type Mode = enum
    hfeNil, hfeDumpHeader
var mode : Mode = hfeNil

for kind, key, val in getopt(commandLineParams()):
    case kind
    of cmdArgument:
        if filename == "":
            filename = key
    of cmdLongOption, cmdShortOption:
        case key
        of "help", "h":
            usage()
        of "header", "d": mode = hfeDumpHeader
    of cmdEnd:
        assert(false)

if filename == "":
    usage()
else:
    # begin parsing
    case mode
    of hfeDumpHeader:
        dumpHfeHeader(filename)
    else: usage()
