# TODO

-   After quit / restart, sounds play faster. Looks like I'm restoring the default timer frequency and unhooking INT 8 correctly. Does this happen on the real PCjr?

-   In game_loop, make a cleaner separation between redrawing the screen and the rest of the game logic.

    -   Process keys should only set a direction vector, not move the player location, on arrow keys. The player location should then be updated only on redraw.
    -   Once this is done, move keyboard processing to game logic section.

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
| 5/28/2025 |   5.61 |      | Honestly I don't know how we gained 0.04 seconds?          |
