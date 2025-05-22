import struct

def read_varlen( buf, offset ):
    v = []
    while buf[offset] & 0x80:
        v.append( buf[offset] )
        offset += 1
    v.append( buf[offset] )
    offset += 1
    return 1, offset

    

with open( "amongus.mid", 'rb' ) as f:
    buf = f.read()

offset = 0

str_header = '>4sIHHH'
str_trackheader = '>4sI'

sig, len_hdr, fmt, num_tracks, division = struct.unpack_from( str_header, buf, offset )

offset += struct.calcsize( str_header )

for i in range( num_tracks )
    sig, len_track = struct.unpack_from( str_trackheader, buf, offset )
    offset += struct.calcsize( str_trackheader )
    track_end = offset + len_track
    while offset < track_end:
        val, offset = read_varlen( buf, offset )
        event = buf[offset]
        offset += 1
        print( "event type {event:02x}")

