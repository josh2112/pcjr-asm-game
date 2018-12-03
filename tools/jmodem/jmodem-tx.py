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
        self.paknum, self.totalpaks = 0, math.ceil( size/128 )
        while file.peek():
            packet = self.make_packet( file )
            packet_enc = bytes( packet )
            print( "Sending packet {}/{}".format( packet[1], self.totalpaks ))
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
        packet = [SOH]
        packet += self.paknum.to_bytes( 2, 'little' )
        packet += self.totalpaks.to_bytes( 2, 'little' )
        packet += file.read( 133-len(packet))
        packet.extend( [0] * (133-len(packet))) # pad with zeroes up to 133
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
        if filesize > 32000:
            print( "Too big to send!" )
            sys.exit

        with open( args.path, 'rb' ) as file:
            print( "Sending file '{}' ({} bytes)...".format( args.path, filesize ))
            JModemSender( serial ).send( file, os.path.basename( args.path ), filesize )

        print( "Done!" )
