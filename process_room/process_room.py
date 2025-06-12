import argparse
import typing

import click
from PIL import Image
from PIL.ImagePalette import ImagePalette

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Converts a PNG image into a format that can be \
        copied directly into PCjr video memory. Given a 160x200 indexed PNG file, packs each \
        pixel into a byte (4bpp indexed), and outputs the result to another file."
    )
    parser.add_argument(
        "pic", type=argparse.FileType("rb"), help="path to picture input file"
    )
    parser.add_argument(
        "depth", type=argparse.FileType("rb"), help="path to depth input file"
    )
    parser.add_argument("bin", type=argparse.FileType("wb"), help="path to output file")
    args = parser.parse_args()

    args.bin.write(
        bytes(
            (depth << 4) | (pic & 0xF)
            for pic, depth in zip(
                list(Image.open(args.pic).getdata()),
                list(Image.open(args.depth).getdata()),
            )
        )
    )
    args.bin.close()


@click.group()
def cli():
    pass


def parse(palstr):
    return [
        b
        for line in (ln for ln in (ln.strip() for ln in palstr.split("\n")) if ln)
        for b in tuple([int(line[i : i + 2], 16) for i in (1, 3, 5)])
    ]


CGA_PAL = parse("""
    #000000 black
    #0000AA blue
    #00AA00 green
    #00AAAA cyan
    #AA0000 red
    #AA00AA magenta
    #AA5500 brown
    #AAAAAA light gray
    #555555 dark gray
    #5555FF light blue
    #55FF55 light green
    #55FFFF light cyan
    #FF5555 light red
    #FF55FF light magenta
    #FFFF55 yellow
    #FFFFFF white
""")


@cli.command()
@click.argument("input", type=click.File("rb"))
@click.argument("offset", type=str)
@click.argument("length", type=str)
def mem2bin(input: typing.IO, offset: str, length: str):
    """Extracts a memory region from a binary file. INPUT is the binary file, OFFSET is the offset to
    start extracting from, and LEN is the number of bytes to extract."""

    offset, length = int(offset, base=16), int(length, base=16)

    # KQ1:
    # - 3a080: depth
    # - 453c0: interleaved depth and color are seemingly being drawn at the same time?

    with open(input.name, "rb") as f:
        f.seek(offset)
        data = f.read(length)
        w, h = 320, length // 320

        img = Image.new("P", (w, h))
        img.putpalette(CGA_PAL)
        img.putdata([d for d in data[: w * h]])
        img.show()
        img.save("depth.png")


def main() -> None:
    cli()
