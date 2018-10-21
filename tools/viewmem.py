import argparse
import os
import math
import sys
import tkinter as tk
from tkinter import font as tkFont

from PIL import Image, ImageTk

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

class TkinterConfigInterceptorMixin( tk.Widget ):
    def add_args( self, args, **kwargs ):
        if not hasattr( self, "_args" ): self._args = {}
        for k,v in kwargs.items():
            self._args[k] = v
            self.__dict__[k] = v
            kwargs.setdefault( k, v )

    def config( self, **kwargs ):
        for k,v in self._args.items():
            if k in kwargs:
                self.__dict__[k] = kwargs.pop( k )
                self.config_arg_changed( k, v )
                # TODO: Notify changed!
                # if self.intvar:
                #     self.intvar.trace( "w", lambda *_: self.valueText.set( str( self.intvar.get() ) ))
        return super().config( **kwargs )
    
    def cget( self, key ):
        return self.__dict__[key] if key in self._args else super().cget( key )

    def config_arg_changed( self, key, val ): pass


class SpinboxWithMouseWheel( tk.Spinbox, TkinterConfigInterceptorMixin ):
    def __init__( self, *args, **kwargs ):
        tk.Spinbox.__init__( self, *args )
        self.add_args( kwargs, intvar=None )
        self.valueText = tk.StringVar()
        self.valueText.set( str( self.intvar.get() if self.intvar else 0 ))
        TkinterConfigInterceptorMixin.config( self, **kwargs, textvariable=self.valueText )
        self.bind( '<MouseWheel>', lambda evt: self.invoke( 'button' + ('up' if evt.delta > 0 else 'down' )))

    def on_intvar_updated( self, val ): self.valueText.set( val )

    def config_arg_changed( self, key, val ):
        if key == "intvar":
            self.intvar.trace( "w", lambda *_: self.on_intvar_updated( self.intvar.get() ))


class HexSpinboxWithMouseWheel( SpinboxWithMouseWheel ):
    def __init__( self, *args, **kwargs ):
        self.add_args( kwargs, increment=1, format="04X" )
        super().__init__( *args, **kwargs )
        tk.Spinbox.config( self, increment=0 )
        self.config( command=(self.register( self.spinhex ), '%s', '%d' ))

    def spinhex( self, value, dir ):
        from_, to_ = int( self.cget( "from" )), int( self.cget( "to" ))
        wrap = bool( self.cget( "wrap" ))
        val = int( value, 16 )
        val += self.increment if dir == 'up' else -self.increment
        if val > to_: val = from_ if wrap else to_
        if val < from_: val = to_ if wrap else from_
        self.intvar.set( val )

    def on_intvar_updated( self, val ):
        self.valueText.set( format( val, self.format ))

class ViewMemWindow( tk.Frame ):
    def __init__( self, parent ):
        tk.Frame.__init__( self, parent )
        self.parent = parent
        
        self.memory, self.region = [], []

        self.offsetVar, self.lengthVar = tk.IntVar(), tk.IntVar()
        self.offsetVar.trace( "w", lambda *_: self.on_offset_updated() )
        self.lengthVar.trace( "w", lambda *_: self.on_length_updated() )

        frame = tk.Frame( self )
        frame.pack( side=tk.LEFT, padx=10 )
        
        self.imgContainer = tk.Canvas( self )
        self.imgContainer.pack( fill=tk.BOTH, expand=1 )

        tk.Label( frame, text="Offset" ).grid( row=0, column=1 )
        tk.Label( frame, text='0x' ).grid( row=1, column=0 )
        self.offsetSpinner = HexSpinboxWithMouseWheel( frame, justify=tk.RIGHT, intvar=self.offsetVar, to_=0 )
        self.offsetSpinner.grid( row=1, column=1 )

        tk.Label( frame, text="Length" ).grid( row=2, column=1 )
        self.lengthSpinner = SpinboxWithMouseWheel( frame, justify=tk.RIGHT, intvar=self.lengthVar, to_=0 )
        self.lengthSpinner.grid( row=3, column=0, columnspan=2, sticky=tk.EW )

        self.pack( fill=tk.BOTH, expand=1 )

    @property
    def offset( self ): return self.offsetVar.get()
    @property
    def length( self ): return self.lengthVar.get()
    
    def on_offset_updated( self ):
        tmp = self.length
        self.lengthSpinner.config( to_=len(self.memory)-self.offset )
        if self.length != tmp: self.lengthVar.set( tmp )
        self.updateImage()
    
    def on_length_updated( self ):
        # Setting a spinner's "from" or "to" resets the value, grumble grumble
        tmp = self.offset
        self.offsetSpinner.config( to_=len(self.memory)-self.length )
        if self.offset != tmp: self.offsetVar.set( tmp )
        self.updateImage()
    
    def loadDump( self, path ):
        self.parent.title( f"{path} - {os.path.basename( __file__ )}" )
        dumpext = os.path.splitext( os.path.basename( path ))[1]
        self.memory = readbin( path ) if dumpext.lower() == '.bin' else readtxt( path )
        self.offsetVar.set( 0x3a080 )
        self.lengthVar.set( 27040 )

    def updateImage( self ):
        if not len(self.memory): return
        imgbytes = []
        for b in self.memory[self.offset:self.offset+self.length]:
            hi = b & 0xf0
            hi |= hi >> 4
            imgbytes.append( hi & 0xf )
            lo = b & 0x0f
            imgbytes.append( lo )
        
        padBytes = math.ceil((self.length*2)/320) * 320 - len(imgbytes)
        imgbytes += [0] * padBytes

        print( "imgbytes size = ", len(imgbytes))
        print( "expecting = ", (320*169))
        
        img = Image.frombytes( 'P', (320,169), bytes( imgbytes ), 'raw' )
        img.putpalette( pcjr16colorpal )
        self.image = ImageTk.PhotoImage( img.resize( (320*3, 169*3) ) )
        self.imgContainer.create_image( 0, 0, image=self.image )


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
    win = ViewMemWindow( root )
    
    win.loadDump( args.dumppath )
    
    root.mainloop()
