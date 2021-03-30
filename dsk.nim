import os
import streams
import strformat
import parseopt
import strutils
import hashes

proc insertFilenameTag(input_filename: string, filename_tag : string) : string =
    var (dir, old_filename, old_extension) = splitFile(input_filename)
    return joinPath(dir, old_filename & filename_tag & old_extension) # addFileExt acts weird here

proc doubleTracksInImage(input_filename : string) =
    # first, count up the size... we want it to make sense
    # should be 40 tracks * 1 side * 16 sectors/track * 256bytes/sector
    const TRACKS = 40
    const SIDES = 1
    const SECTORS = 16
    const BYTES_PER_SECTOR = 256
    const TRACK_LENGTH = SIDES * SECTORS * BYTES_PER_SECTOR;
    const SIZE_1D_IMAGE = TRACKS * TRACK_LENGTH;

    var disk_buffer: array[SIZE_1D_IMAGE, char]
    var fs = newFileStream(input_filename, fmRead) # TODO: Win32 binary file argument needed?
    defer: fs.close()
    if not fs.isNil: # FIXME: crash otherwise
        # read the entire thing into an array
        doAssert fs.readData(addr(disk_buffer), SIZE_1D_IMAGE) == SIZE_1D_IMAGE, fmt"Image wasn't long enough; it might not be a 40-track PC-6601 image (expected exactly {SIZE_1D_IMAGE} bytes)"
        doAssert fs.atEnd() == true, fmt"Image had leftover data; it might not be a 40-track PC-6601 image (expected exactly {SIZE_1D_IMAGE} bytes)"
        doAssert fs.getPosition() == SIZE_1D_IMAGE # extra paranoid
    
    # okay the buffer is valid, let's extract a track at a time and then double it up in the result
    # TODO: should I check to make sure that this file doesn't already exist?
    var output_filename = insertFilenameTag(input_filename, ".80track-doubled")
    var output = newFileStream(output_filename, fmWrite)
    defer: output.close()
    
    var i = 0
    while i < len(disk_buffer):
        # write the track twice in a row
        for copy_number in 0..1:
            for j in 0 ..< TRACK_LENGTH:
                output.write(disk_buffer[i + j]);
        # continue in the source array
        i += TRACK_LENGTH;

    # assert that we wrote the right length
    output.flush()
    doAssert output.getPosition() == SIZE_1D_IMAGE * 2, "Should have written exactly twice as many bytes when doubling the image"

proc dumpTracks(input_filename : string) =
    const SIDES = 1
    const SECTORS = 16
    const BYTES_PER_SECTOR = 256
    const TRACK_LENGTH = SIDES * SECTORS * BYTES_PER_SECTOR;

    var track_buffer: array[TRACK_LENGTH, char]
    var track_number = 1

    var fs = newFileStream(input_filename, fmRead)
    defer: fs.close()
    if not fs.isNil:
        stdout.write alignLeft(fmt("trk#"), 6)
        stdout.write alignLeft(fmt("hash"), 12)
        stdout.write alignLeft(fmt("preview"), 12)
        echo ""
        while not fs.atEnd():
            doAssert fs.readData(addr(track_buffer), TRACK_LENGTH) == TRACK_LENGTH, "Image is wrong length to contain a whole number of tracks"

            stdout.write alignLeft(fmt("{track_number}"), 6)
            stdout.write alignLeft(fmt("{hash(track_buffer)}"), 12)

            for i in 0 ..< 6:
                stdout.write fmt"{toHex(cast[int](track_buffer[i]), 2)}"
                stdout.write " "

            echo ""
            
            track_number += 1

proc expand40TrackImage(input_filename : string) =
    # append 40 tracks of FF onto the end, and change any "SYS" tag to "RXR"
    const SIDES = 1
    const SECTORS = 16
    const BYTES_PER_SECTOR = 256
    const TRACK_LENGTH = SIDES * SECTORS * BYTES_PER_SECTOR;
    const FORTY_TRACK_IMAGE_LENGTH = TRACK_LENGTH * 40

    var fs = newFileStream(input_filename, fmRead)
    defer: fs.close()

    var track_buffer : array[FORTY_TRACK_IMAGE_LENGTH, char]

    if not fs.isNil: # FIXME: crash otherwise
        doAssert fs.readData(addr(track_buffer), FORTY_TRACK_IMAGE_LENGTH) == FORTY_TRACK_IMAGE_LENGTH, "Image is wrong length to contain a whole number of tracks"
        doAssert fs.atEnd() == true
    else:
        doAssert false

    # fixup the SYS -> RXR so we don't double step
    track_buffer[0] = 'R' # TODO: maybe check first in case we're breaking the image
    track_buffer[1] = 'X'
    track_buffer[2] = 'R'

    var output_filename = insertFilenameTag(input_filename, ".80track-expanded")
    var output = newFileStream(output_filename, fmWrite)
    defer: output.close()

    for i in 0 ..< len(track_buffer):
        output.write(track_buffer[i])

    for i in 0 ..< len(track_buffer):
        output.write(cast[byte](0xFF))

    output.flush()
    doAssert output.getPosition() == FORTY_TRACK_IMAGE_LENGTH * 2;

proc usage() =
    echo fmt"Usage: {lastPathPart(paramStr(0))} [command] filename"
    echo "Commands: --help, --double, --tracks"

var filename: string
type Mode = enum
    dskNil, dskDouble40TrackImage, dskGetInfo, dskExpand40TrackImage
var mode : Mode = dskNil

for kind, key, val in getopt(commandLineParams()):
    case kind
    of cmdArgument:
        filename = key
    of cmdLongOption, cmdShortOption:
        case key
        of "help", "h": usage()
        of "double", "d": mode = dskDouble40TrackImage
        of "expand", "e": mode = dskExpand40TrackImage
        of "tracks", "t": mode = dskGetInfo
    of cmdEnd:
        assert(false)

if filename == "":
    usage()
else:
    # begin parsing
    case mode
    of dskDouble40TrackImage: doubleTracksInImage(filename)
    of dskGetInfo: dumpTracks(filename)
    of dskExpand40TrackImage: expand40TrackImage(filename)
    else: usage()
