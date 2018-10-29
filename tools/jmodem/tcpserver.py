#!/usr/bin/env python3
#
# TCP multicast server
# Accepts connections from multiple clients. Relays data from any client
# to all other clients.

import asyncio

hostaddr = ('localhost', 7000)

addr_to_str = lambda addr: ':'.join( str(x) for x in addr[:2] )

async def hub_server( reader, writer, clients, lock ):
    myaddr = writer.get_extra_info( 'peername' )
    print( "Client {} connected".format( addr_to_str(myaddr)))
    async with lock: clients[myaddr] = writer
    try:
        while True:
            data = await reader.read( 128 )
            if not data: break
            print( "Got: ", data )
            async with lock:
                destinations = {addr:writer for (addr,writer) in clients.items() if addr != myaddr}
                if destinations:
                    print( "{} byte(s) {} => {}".format( len(data), addr_to_str(myaddr), [addr_to_str(x) for x in destinations.keys()] ))
                    for w in destinations.values():
                        w.write( data )
    finally:
        async with lock: del clients[myaddr]
        print( "Client {} disconnected".format( addr_to_str(myaddr)))


clients = {}
lock = asyncio.Lock()

loop = asyncio.get_event_loop()
coro = asyncio.start_server( lambda r,w: hub_server( r, w, clients, lock ), *hostaddr, loop=loop )
server = loop.run_until_complete( coro )

print( "Serving on {}".format( addr_to_str(hostaddr) ))

try: loop.run_forever()
except KeyboardInterrupt: pass

server.close()
loop.run_until_complete( server.wait_closed() )
loop.close()
