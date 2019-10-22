from PIL import Image
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser( description="Converts a PNG image into a format that can be copied directly into PCjr video memory. \
        Given a 320x200 indexed PNG file, packs each pair of pixels into a byte (4pbb indexed), \
        and outputs the result to another file." )
    parser.add_argument( 'png', type=argparse.FileType('rb'), help='path to PNG input file' )
    parser.add_argument( 'bin', type=argparse.FileType('wb'), help='path to output file' )
    args = parser.parse_args()

    pixels = list( Image.open( args.png ).getdata())

    args.bin.write( bytes( (pxpair[0] << 4) | pxpair[1] for pxpair in zip( pixels[::2], pixels[1::2] ) ) )
    args.bin.close()