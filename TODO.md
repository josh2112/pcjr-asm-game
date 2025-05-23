# TODO

- Python MIDI parser / SND encoder works, and ASM sound decoder / player works as well. But:

  1. The timing resolution is not great. With the tick resolution of 55 msec, 120 BPM has 9 ticks per beat. This leads to sketchy 8th notes (sometimes 4 ticks long, sometimes 5). Can we change the resolution of the ticker? Or use another timing method?
  2. With 10-bit frequency resolution of the CSG, octave 2 G# (103.83 Hz, MIDI note 44) is as low as we can go. We'll probably need to make much lower sounds than that. Investigate the other method of sound production (but that only gets us 1 channel at a time!)

- Animate walking

# Timings

|      Date | DOSBox | PCjr | Notes                                                      |
| --------: | -----: | ---: | ---------------------------------------------------------- |
|  5/1/2025 |   5.33 |      |                                                            |
|  5/4/2025 |        | 5.61 | Conversion of calc_pixel_offset to 1-byte values           |
|  5/5/2025 |        | 6.92 | Added copy FB to BG                                        |
| 5/12/2025 |   8.04 | 8.29 | Added copy BG to compositor                                |
| 5/14/2025 |   8.35 | 8.24 | Optimization of vector file                                |
| 5/15/2025 |   9.17 | 9.11 | Added way more depth stuff                                 |
| 5/16/2025 |   7.80 | 7.62 | Replaced playset with swings                               |
| 5/20/2025 |   6.42 | 6.33 | Avoid filling compositor initially (saves 1.3 sec!)        |
| 5/20/2025 |   5.65 | 5.28 | Converted fill to 1-byte words; byte-extend color up front |
