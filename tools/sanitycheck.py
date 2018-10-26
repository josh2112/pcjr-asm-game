#!/usr/bin/env python3

import asyncio
import sys
import serial

async def hub_server( reader, writer ):
    data = await reader.read( 10 )
    print( "Received: ", data )
    await writer.write( "got it".encode() )

if sys.argv[1] == "server":
    loop = asyncio.get_event_loop()
    coro = asyncio.start_server( hub_server, 'localhost', 7000, loop=loop )
    server = loop.run_until_complete( coro )

    try: loop.run_forever()
    except KeyboardInterrupt: pass

    server.close()
    loop.run_until_complete( server.wait_closed() )
    loop.close()
else:
    with serial.serial_for_url( "socket://localhost:7000", baudrate=1200 ) as serial:
        serial.write( "hello world".encode() )
        response = serial.read( 6 )
        print( "Received: ", response )