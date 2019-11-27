#!/usr/bin/env python3

from PIL import Image
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser( description="Converts a PNG image into a format that can be \
        copied directly into PCjr video memory. Given a 160x200 indexed PNG file, packs each \
        pixel into a byte (4bpp indexed), and outputs the result to another file." )
    parser.add_argument( 'pic', type=argparse.FileType('rb'), help='path to picture input file' )
    parser.add_argument( 'depth', type=argparse.FileType('rb'), help='path to depth input file' )
    parser.add_argument( 'bin', type=argparse.FileType('wb'), help='path to output file' )
    args = parser.parse_args()

    args.bin.write( bytes( (depth << 4) | (pic & 0xf) \
        for pic,depth in zip( \
            list( Image.open( args.pic ).getdata()),
            list( Image.open( args.depth ).getdata()) ) ) )
    args.bin.close()