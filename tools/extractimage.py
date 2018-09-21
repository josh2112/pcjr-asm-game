#!/bin/python

import sys
from PIL import Image

def getarg( i, default ):
    try: return sys.argv[i]
    except: return default

path = getarg( 1, "../scratchpad/memdump2.txt" )
offset = int( getarg( 2,"0x3a080" ), 16 )
length = int( getarg( 3,"27040" ))

with open( path, 'r' ) as f:
    lines = [line.split()[1:] for line in f.readlines()]
    memory = [int(v, 16) for line in lines for v in line]

region = memory[offset:offset+length]

r1, r2 = [],[]
for b in region:
    lo = b & 0xf
    lo |= lo << 4
    hi = b & 0xf0
    hi |= hi >> 4
    r1 += [lo] * 2
    r2 += [hi] * 2

im1 = Image.frombytes( 'P', (320,169), bytes( r1 ), 'raw')
im1.save( '../scratchpad/r1.png' )

im2 = Image.frombytes( 'P', (320,169), bytes( r2 ), 'raw')
im2.save( '../scratchpad/r2.png' )