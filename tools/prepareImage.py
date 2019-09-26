import argparse
import tkinter as tk
from PIL import Image, ImageOps, ImageTk

pal_picture = (
    (0, 0, 0), (0, 0, 170), (0, 170, 0), (0, 170, 170), # Bk Bl Gn Cy
    (170, 0, 0), (170, 0, 170),  (170, 85, 0), (170, 170, 170), # Rd Mg Br LGr
    (85, 85, 85), (85, 85, 255), (85, 255, 85), (85, 255, 255), # DG LBl LGn LCy
    (255, 85, 85), (255, 85, 255), (255, 255, 85), (255, 255, 255) # LR LM LY Wh
)
pal_picture += ((0,0,0),) * (256-len(pal_picture))
pal_picture = [i for t in pal_picture for i in t]

def resize( img ):
    return img.resize( (160,168), Image.LANCZOS )

def quantize( img ):
    img.load()
    palImg = Image.new( 'P', (16,16))
    palImg.putpalette( pal_picture )
    palImg.load()
    return img._new( img.im.convert( 'P', 0, palImg.im ))

class App( tk.Frame ):
    def __init__( self, master, img ):
        tk.Frame.__init__(self, master)
        self.original = img
        self.columnconfigure(0,weight=1)
        self.rowconfigure(0,weight=1)
        self.image = ImageTk.PhotoImage(self.original)
        self.display = tk.Canvas(self, bd=0, highlightthickness=0)
        self.display.create_image(0, 0, image=self.image, anchor=tk.NW, tags="IMG")
        self.display.grid(row=0, sticky=tk.W+tk.E+tk.N+tk.S)
        self.pack(fill=tk.BOTH, expand=1)
        self.bind("<Configure>", self.resize)

    def resize(self, event):
        size = (event.width, event.height)
        resized = self.original.resize(size)
        self.image = ImageTk.PhotoImage(resized)
        self.display.delete("IMG")
        self.display.create_image(0, 0, image=self.image, anchor=tk.NW, tags="IMG")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Processes a picture or priority image' )
    parser.add_argument( 'type', choices=['pic', 'pri'], help='image type' )
    parser.add_argument( 'input_path', type=argparse.FileType( 'rb' ))
    parser.add_argument( 'output_path', type=argparse.FileType( 'wb' ))
    args = parser.parse_args()

    img = Image.open( args.input_path ).convert( "RGB" )

    img = resize( img )
    img = quantize( img )
    img.save( args.output_path )

    window = tk.Tk()
    window.geometry( 'x'.join( [str(i*3) for i in (320,168)] ) )
    app = App( window, img )
    app.mainloop()