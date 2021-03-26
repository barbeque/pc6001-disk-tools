import os, sys

# force the media type of a target d88 to 1DD for use on a PC-6601SR

filename = sys.argv[1]
with open(filename, 'rb') as f:
	data = bytearray(f.read())

# force it to a 1DD format disk (0x40)
# because HxC doesn't know what 1D (0x30) is
old_media_type = data[0x1b]
data[0x1b] = 0x40
print(f'Converting media type {hex(old_media_type)} to {hex(0x40)}')

with open('1dd-' + filename, 'wb') as f:
	f.write(data)
