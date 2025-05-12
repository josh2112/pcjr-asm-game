# TODO

- Add support for reading from ROM BIOS area (0xf0000-0xfffff) to EmuJr

- Depth vector drawing seems to work? Maybe more testing?

- Add depth info to room1.rsc (using the existing room1-depth.png as an overlay)

  - Then get rid of binary image stuff!

- Could fill() be rewritten to take 1-byte values since X axis only goes to 160 now?

# Timings

|      Date | DOSBox | PCjr | Notes                                            |
| --------: | -----: | ---: | ------------------------------------------------ |
|  5/1/2025 |   5:33 |      |                                                  |
|  5/4/2025 |        | 5:61 | Conversion of calc_pixel_offset to 1-byte values |
|  5/5/2025 |        | 6:92 | With depth rendering + copy                      |
| 5/12/2025 |   8:04 | 8:29 | Added copy background to compositor              |
