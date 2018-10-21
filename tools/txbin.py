#!/usr/bin/env python

import serial
import argparse

#url = "socket://localhost:7000"
url = "/dev/tty.UC-232AC" # or something like that

parser = argparse.ArgumentParser( description='Sends a file over the serial port.' )
parser.add_argument( 'path', help='path to the file to send' )
args = parser.parse_args()

with serial.serial_for_url( url, baudrate=300 ) as s:
    s.baudrate = 300
    print( "Opened port {}".format( s.name ) )
    with open( args.path, 'rb' ) as f: data = f.read()
    print( "Sending file '{}' ({} bytes)...".format( args.path, len(data)))
    s.write( data )

print( "Done!" )
