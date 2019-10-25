rsvg-convert.exe ..\room1\room1.svg -i layer1 -w 320 -h 200 -o ..\room1\room1-pic.png
rsvg-convert.exe ..\room1\room1.svg -i layer3 -w 320 -h 200 -o ..\room1\room1-depth.png
python process-room.py ..\room1\room1-pic.png ..\room1\room1-depth.png ..\room1.bin