#!/usr/bin/env python

import serial
import argparse

url = "socket://localhost:7000"
#url = "/dev/tty.UC232A" # or something like that

parser = argparse.ArgumentParser( description='Sends a file over the serial port.' )
parser.add_argument( 'path', help='path to the file to send' )
args = parser.parse_args()

with serial.serial_for_url( url ) as s:
    print( f"Opened port {s.name}" )
    with open( args.path, 'rb' ) as f: data = f.read()
    print( f"Sending file '{args.path}' ({len(data)} bytes)..." )
    s.write( data )

print( "Done!" )
