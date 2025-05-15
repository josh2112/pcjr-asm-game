# TODO

- Get rid of all traces of binary image stuff!

- Add screen boundaries

- Could fill() be rewritten to take 1-byte values since X axis only goes to 160 now?

# Timings

|      Date | DOSBox | PCjr | Notes                                            |
| --------: | -----: | ---: | ------------------------------------------------ |
|  5/1/2025 |   5.33 |      |                                                  |
|  5/4/2025 |        | 5.61 | Conversion of calc_pixel_offset to 1-byte values |
|  5/5/2025 |        | 6.92 | Added copy FB to BG                              |
| 5/12/2025 |   8.04 | 8.29 | Added copy BG to compositor                      |
| 5/14/2025 |   8.35 | 8.24 | Optimization of vector file                      |
| 5/15/2025 |   9.17 | 9.11 | Added way more depth stuff                       |
