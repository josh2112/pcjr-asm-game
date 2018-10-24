#!/usr/bin/env python3

import sys, math
import serial
import argparse

STX = 2
ACK = 6
NAK = 21

def make_jmodem_packet( data, paknum ):
    packet = [STX]
    packet.append( paknum )
    start = paknum*128
    end = min( start+128, len(data))
    packet.extend( data[start:end] )
    chksum = sum( data ) % 256
    packet.append( chksum )
    return packet



#url = "socket://localhost:7000"
url = "/dev/tty.UC-232AC" # or something like that

parser = argparse.ArgumentParser( description='Sends a file over the serial port.' )
parser.add_argument( 'path', help='path to the file to send' )
args = parser.parse_args()

with serial.serial_for_url( url, baudrate=1200 ) as s:
    s.baudrate = 1200
    print( "Opened port {}".format( s.name ) )
    with open( args.path, 'rb' ) as f: data = f.read()
    if len(data) > 16384:
        print( "Too big to send!" )
        sys.exit
    print( "Sending file '{}' ({} bytes)...".format( args.path, len(data)))

    for paknum in range( 0, math.ceil( len(data)/128 )):
        while True:
            packet = make_jmodem_packet( data, paknum )
            print( "Writing packet {}".format( paknum ))
            s.write( packet )
            result = s.read( 1 )[0]
            if result == ACK: break
            elif result == NAK:
                print( "NAK received, resending packet" )
            else:
                print( "Unknown response received!" )
                sys.exit()

print( "Done!" )
