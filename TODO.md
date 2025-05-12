# TODO

- Depth vector drawing seems to work? Maybe more testing?

- Could fill() be rewritten to take 1-byte values since X axis only goes to 160 now?

# Timings

|     Date | DOSBox | PCjr | Notes                                            |
| -------: | -----: | ---: | ------------------------------------------------ |
| 5/1/2025 |   5.33 |      |                                                  |
| 5/4/2025 |        | 5.61 | Conversion of calc_pixel_offset to 1-byte values |
| 5/5/2025 |        | 6.92 | With depth rendering + copy                      |
