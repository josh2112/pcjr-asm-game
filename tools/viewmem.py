import tkinter as tk
from tkinter import font as tkFont
from PIL import Image, ImageTk

import os, sys
import argparse

pcjr16colorpal = [
    0, 0, 0, 0, 0, 170, 0, 170, 0, 0, 170, 170, 170, 0, 0, 170, 0, 170, 170, 85, 0, 170, 170, 170,
    85, 85, 85, 85, 85, 255, 85, 255, 85, 85, 255, 255, 255, 85, 85, 255, 85, 255, 255, 255, 85, 255, 255, 255
]
pcjr16colorpal += [0] * (768-len(pcjr16colorpal))

def readtxt( path ):
    with open( path, 'r' ) as f:
        lines = [line.split()[1:] for line in f.readlines()]
        return [int(v, 16) for line in lines for v in line]

def readbin( path ):
    with open( path, 'rb' ) as f:
        return f.read()

def takeADump( region, basename ):
    rRaw, rLo, rHi = [], [], []
    for b in region:
        lo = b & 0x0f
        rLo += [lo] * 2

        hi = b & 0xf0
        hi |= hi >> 4
        rHi += [hi] * 2

        #rRaw.append( hi & 0xf )
        #rRaw.append( lo )

    #img = Image.frombytes( 'P', (320,169), bytes( rRaw ), 'raw' )
    #img.putpalette( pcjr16colorpal )
    #img.save( basename + '-raw.png' )

    img = Image.frombytes( 'P', (320,169), bytes( rLo ), 'raw' )
    img.putpalette( pcjr16colorpal )
    img.save( basename + '-lo.png' )

    img = Image.frombytes( 'P', (320,169), bytes( rHi ), 'raw' )
    img.save( basename + '-hi.png' )

def validateOffsetEntry( potential_value ):
    try: potential_value == '' or int( potential_value, 16 )
    except: return False
    return True

def validateLengthEntry( potential_value ):
    try: potential_value == '' or int( potential_value )
    except: return False
    return True

class SpinboxWithMouseWheel( tk.Spinbox ):
    def __init__( self, *args, **kwargs ):
        tk.Spinbox.__init__( self, *args, **kwargs )
        self.bind( '<MouseWheel>', lambda evt: self.invoke( 'button' + ('up' if evt.delta > 0 else 'down' )))

class HexSpinboxWithMouseWheel( tk.Spinbox ):
    def __init__( self, *args, **kwargs ):
        SpinboxWithMouseWheel.__init__( self, *args, **kwargs )
        self.config( increment=0, command=(self.register( self.spinhex ), '%s', '%d', '%%04X' ))

    def spinhex( self, value, dir, format ):
        self.form
        w.set( format( value, 'x' ))

class ViewMemWindow( tk.Frame ):
    def __init__( self, parent ):
        tk.Frame.__init__( self, parent )
        self.parent = parent
        
        self.memory, self.region = None, None

        self.offsetText, self.lengthText = tk.StringVar(), tk.StringVar()
        self.offsetText.trace( "w", lambda *_: self.updateImage() )
        self.lengthText.trace( "w", lambda *_: self.updateImage() )

        frame = tk.Frame( self )
        frame.pack( side=tk.LEFT, padx=10 )
        
        self.canvas = tk.Canvas( self )
        self.canvas.pack( fill=tk.BOTH, expand=1 )

        tk.Label( frame, text="Offset" ).grid( row=0, column=1 )
        tk.Label( frame, text='0x' ).grid( row=1, column=0 )
        tk.Entry( frame, justify=tk.RIGHT, textvariable=self.offsetText, validate='key',
            validatecommand=(self.register( validateOffsetEntry ), '%P' ) ).grid( row=1, column=1 )

        tk.Label( frame, text="Length" ).grid( row=2, column=1 )
        tk.Entry( frame, justify=tk.RIGHT, textvariable=self.lengthText, validate='key',
            validatecommand=(self.register( validateLengthEntry ), '%P' ) ).grid( row=3, column=0, columnspan=2, sticky=tk.EW )

        offsetSpinner = HexSpinboxWithMouseWheel( frame, from_=0, to_=0x100000 )
        offsetSpinner.grid( row=4, columnspan=2 )
        lengthSpinner = SpinboxWithMouseWheel( frame, from_=0, to_=0x100000 )
        lengthSpinner.grid( row=5, columnspan=2 )

        self.offsetText.set( format( 0x3a080, 'x' ))
        self.lengthText.set( str( 27040 ))
        
        self.pack( fill=tk.BOTH, expand=1 )
    
    def offset( self ): return int( self.offsetText.get(), 16 )
    def length( self ): return int( self.lengthText.get() )

    def loadDump( self, path ):
        self.parent.title( f"{path} - {os.path.basename( __file__ )}" )
        _, dumpext = os.path.splitext( os.path.basename( path ))
        self.memory = readbin( path ) if dumpext.lower() == '.bin' else readtxt( path )
        self.updateImage()

    def updateImage( self ):
        if self.memory:
            self.region = self.memory[self.offset():self.offset()+self.length()]


if __name__ == '__main__':
    parser = argparse.ArgumentParser( description='Views a subset of a RAM dump as an image, applying the PCjr 16-color CGA palette to it.' )
    parser.add_argument( 'dumppath', help='Path to the RAM dump to process. Can be either binary or a DOSBOX debug text dump.' )
    args = parser.parse_args()

    #dumpregion = False
    #if dumpregion:
    #    takeADump( region, dumpname )
    #    sys.exit()

    root = tk.Tk()
    tkFont.nametofont( "TkDefaultFont" ).configure( size=12 )
    tkFont.nametofont( "TkTextFont" ).configure( size=12 )
    win = ViewMemWindow(root)
    
    win.loadDump( args.dumppath )
    
    root.mainloop()
