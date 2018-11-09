#!/usr/bin/env python3

import sys, math, os
import serial
import argparse

#url = "socket://localhost:7000"
url = "/dev/tty.UC-232AC"

SOH = 1
ACK = 6
NAK = 21

class JModemSender:
    def __init__( self, serial ):
        self.serial = serial
    
    def send( self, file, name, size ):
        self.paknum = 0
        while file.peek():
            packet = self.make_header_packet( file, name, size ) if self.paknum == 0 else self.make_packet( file )
            packet_enc = bytes( packet )
            print( "Sending packet {}".format( packet[1] ))
            while True:
                self.serial.write( packet_enc )
                response = self.serial.read( 1 )[0]
                if response == ACK:
                    break
                elif response == NAK:
                    print( "NAK received, resending packet" )
                else:
                    print( "Unknown response received ({})!".format( response ) )
                    return
            self.paknum += 1
    
    def make_packet( self, file ):
        packet = [SOH, self.paknum]
        packet += file.read( 130-len(packet))
        packet.extend( [0] * (130-len(packet))) # pad with zeroes up to 130
        packet += [sum( packet ) % 256]
        return packet

    def make_header_packet( self, file, name, size ):
        packet = [SOH, self.paknum, len(name)]
        packet += [ord(c) for c in name]
        packet += size.to_bytes( 2, 'little' )
        print( "Filling the packet with up to {} bytes".format( 130-len(packet)))
        filedata = file.read( 130-len(packet))
        packet += filedata
        packet.extend( [0] * (130-len(packet))) # pad with zeroes up to 130
        packet += [sum( packet ) % 256]
        return packet


if __name__=="__main__":
    parser = argparse.ArgumentParser( description='Sends a file over the serial port.' )
    parser.add_argument( 'path', help='path to the file to send' )
    args = parser.parse_args()

    with serial.serial_for_url( url, baudrate=1200 ) as serial:
        print( "Opened port {}".format( serial.name ) )
        serial.baudrate = 1200
        
        filesize = os.stat( args.path ).st_size
        if filesize > 16384:
            print( "Too big to send!" )
            sys.exit

        with open( args.path, 'rb' ) as file:
            print( "Sending file '{}' ({} bytes)...".format( args.path, filesize ))
            JModemSender( serial ).send( file, os.path.basename( args.path ), filesize )

        print( "Done!" )
