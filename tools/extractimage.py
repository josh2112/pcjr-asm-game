#!/bin/python

import sys
import os
from PIL import Image

def getarg( i, default ):
    try: return sys.argv[i]
    except: return default

def readtxt( path ):
    with open( path, 'r' ) as f:
        lines = [line.split()[1:] for line in f.readlines()]
        return [int(v, 16) for line in lines for v in line]

def readbin( path ):
    with open( path, 'rb' ) as f:
        return f.read()

pcjr16colorpal = [
    0, 0, 0, 0, 0, 170, 0, 170, 0, 0, 170, 170, 170, 0, 0, 170, 0, 170, 170, 85, 0, 170, 170, 170,
    85, 85, 85, 85, 85, 255, 85, 255, 85, 85, 255, 255, 255, 85, 85, 255, 85, 255, 255, 255, 85, 255, 255, 255
]
pcjr16colorpal += [0] * (768-len(pcjr16colorpal))

path = getarg( 1, "../scratchpad/memdump.txt" )
offset = int( getarg( 2,"0x3a080" ), 16 )
length = int( getarg( 3,"27040" ))

memory = readbin( path ) if os.path.splitext( path )[1].lower() == '.bin' else readtxt( path )

region = memory[offset:offset+length]

rRaw, rLo, rHi = [], [], []
for b in region:
    lo = b & 0x0f
    rLo += [lo] * 2

    hi = b & 0xf0
    hi |= hi >> 4
    rHi += [hi] * 2

    #rRaw.append( hi & 0xf )
    #rRaw.append( lo )

outputname = os.path.splitext( os.path.basename( path ))[0]

#img = Image.frombytes( 'P', (320,169), bytes( rRaw ), 'raw' )
#img.putpalette( pcjr16colorpal )
#img.save( outputname + '-raw.png' )

img = Image.frombytes( 'P', (320,169), bytes( rLo ), 'raw' )
img.putpalette( pcjr16colorpal )
img.save( outputname + '-lo.png' )

img = Image.frombytes( 'P', (320,169), bytes( rHi ), 'raw' )
img.save( outputname + '-hi.png' )
