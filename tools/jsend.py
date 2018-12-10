#!/usr/bin/env python3

import os, sys
import argparse
import socket

DEST = ("192.168.1.5", 7000)

# class JSender:
#     def __init__( self, serial ):
#         self.serial = serial
    
#     def send( self, file, name, size ):
#         self.paknum, self.totalpaks = 0, math.ceil( size/128 )
#         while file.peek():
#             packet = self.make_packet( file )
#             packet_enc = bytes( packet )
#             print( "Sending packet {}/{}".format( packet[1], self.totalpaks ))
#             while True:
#                 self.serial.write( packet_enc )
#                 response = self.serial.read( 1 )[0]
#                 if response == ACK:
#                     break
#                 elif response == NAK:
#                     print( "NAK received, resending packet" )
#                 else:
#                     print( "Unknown response received ({})!".format( response ) )
#                     return
#             self.paknum += 1
    
#     def make_packet( self, file ):
#         packet = [SOH]
#         packet += self.paknum.to_bytes( 2, 'little' )
#         packet += self.totalpaks.to_bytes( 2, 'little' )
#         packet += file.read( 133-len(packet))
#         packet.extend( [0] * (133-len(packet))) # pad with zeroes up to 133
#         packet += [sum( packet ) % 256]
#         return packet


if __name__ == "__main__":
    parser = argparse.ArgumentParser( description='Sends a file over TCP using JRECV.' )
    parser.add_argument( 'path', help='path to the file to send' )
    args = parser.parse_args()

    print( "Connecting to {0}:{1}...".format( DEST[0], DEST[1] ), end="", flush=True )

    sock = socket.socket( socket.AF_INET, socket.SOCK_STREAM )
    sock.connect( DEST )

    print( "Connected" )

    with open( args.path, 'rb' ) as file:
        name, ext = os.path.splitext( os.path.basename( args.path ))
        filesize = os.stat( args.path ).st_size

        print( "Sending file '{}' ({} bytes)...".format( args.path, filesize ))
        
        msg = bytes( (name[:8] + ext).ljust( 12, '\0' ), 'ascii' )
        msg += filesize.to_bytes( 4, 'big' )
        msg += bytes( file.read())

        totalsent = 0
        while totalsent < len(msg):
            sent = sock.send( msg[totalsent:] )
            if sent == 0:
                raise RuntimeError( "Socket connection broken" )
            totalsent = totalsent + sent
            print( "{0}% ({1} bytes)".format( round( totalsent*100/len(msg)), totalsent ))
            
    print( "Done!" )
