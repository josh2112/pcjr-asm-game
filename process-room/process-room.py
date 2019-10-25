from PIL import Image
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser( description="Converts a PNG image into a format that can be copied directly into PCjr video memory. \
        Given a 320x200 indexed PNG file, packs each pair of pixels into a byte (4pbb indexed), \
        and outputs the result to another file." )
    parser.add_argument( 'pic', type=argparse.FileType('rb'), help='path to picture input file' )
    parser.add_argument( 'depth', type=argparse.FileType('rb'), help='path to depth input file' )
    parser.add_argument( 'bin', type=argparse.FileType('wb'), help='path to output file' )
    args = parser.parse_args()

    pic_pixels = list( Image.open( args.pic ).getdata())
    depth_pixels = list( Image.open( args.depth ).getdata())

    args.bin.write( bytes( (depth << 4) | (pic & 0xf) for pic,depth in zip( pic_pixels[::2], depth_pixels[::2] ) ) )
    args.bin.close()