import os
import streams
import strformat
import parseopt

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
    if not fs.isNil:
        # read the entire thing into an array
        doAssert fs.readData(addr(disk_buffer), SIZE_1D_IMAGE) == SIZE_1D_IMAGE, fmt"Image wasn't long enough; it might not be a 40-track PC-6601 image (expected exactly {SIZE_1D_IMAGE} bytes)"
        doAssert fs.atEnd() == true, fmt"Image had leftover data; it might not be a 40-track PC-6601 image (expected exactly {SIZE_1D_IMAGE} bytes)"
    
    # okay the buffer is valid, let's extract a track at a time and then double it up in the result
    var (dir, old_filename, old_extension) = splitFile(input_filename)
    var output_filename = joinPath(dir, old_filename & ".80track" & old_extension) # addFileExt acts weird here
    # TODO: should I check to make sure that this file doesn't already exist?
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

proc usage() =
    echo fmt"Usage: {lastPathPart(paramStr(0))} [command] filename"
    echo "Commands: --help, --double"

var filename: string
type Mode = enum
    dskNil, dskDouble40TrackImage
var mode : Mode = dskNil

for kind, key, val in getopt(commandLineParams()):
    case kind
    of cmdArgument:
        filename = key
    of cmdLongOption, cmdShortOption:
        case key
        of "help", "h": usage()
        of "double", "d": mode = dskDouble40TrackImage
    of cmdEnd:
        assert(false)

if filename == "":
    usage()
else:
    # begin parsing
    case mode
    of dskDouble40TrackImage: doubleTracksInImage(filename)
    else: usage()
