# TODO

-   Broke fosquest (doesn't fully draw character) with commit 1c0592a7a6cfa9c4fd5359e38ff7a45d9793a571. Investigate!

-   Animate walking

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
| 5/28/2025 |   5.61 | 5.26 | Honestly I don't know how we gained 0.02 seconds?          |
