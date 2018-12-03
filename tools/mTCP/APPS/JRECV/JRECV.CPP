
#include <bios.h>
#include <dos.h>
#include <io.h>
#include <stdlib.h>
#include <string.h>

#include "types.h"
#include "utils.h"
#include "packet.h"
#include "arp.h"
#include "udp.h"
#include "dns.h"
#include "tcp.h"
#include "tcpsockm.h"

// Function prototypes

static void parseArgs( int argc, char *argv[] );
static void shutdown( int rc );

// Global vars and flags

uint16_t LclPort = 7000;         // Local port to use for our socket (0 means not set)

#define RECV_BUFFER_SIZE (1024)
uint8_t recvBuffer[ RECV_BUFFER_SIZE ];

// Trap Ctrl-Break and Ctrl-C so that we can unhook the timer interrupt
// and shutdown cleanly.

// Check this flag once in a while to see if the user wants out.
volatile uint8_t CtrlBreakDetected = 0;

void ( __interrupt __far *oldCtrlBreakHandler)( );

void __interrupt __far ctrlBreakHandler( ) {
  CtrlBreakDetected = 1;
}

void __interrupt __far ctrlCHandler( ) {
  // Do Nothing
}

int main( int argc, char *argv[] ) {
  fprintf( stderr, "JRECV v0.1 (c) 2018 Joshua Foster\n\n" );

  // Read command line arguments
  parseArgs( argc, argv );

  // Setup mTCP environment
  if ( Utils::parseEnv( ) != 0 ) {
    exit(-1);
  }

  // Initialize TCP/IP stack
  if ( Utils::initStack( 2, TCP_SOCKET_RING_SIZE ) ) {
    fprintf( stderr, "\nFailed to initialize TCP/IP - exiting\n" );
    exit(-1);
  }

  // From this point forward you have to call the shutdown( ) routine to
  // exit because we have the timer interrupt hooked.

  // Save off the oldCtrlBreakHander and put our own in.  Shutdown( ) will
  // restore the original handler for us.
  oldCtrlBreakHandler = getvect( 0x1b );
  setvect( 0x1b, ctrlBreakHandler);

  // Get the Ctrl-C interrupt too, but do nothing.  We actually want Ctrl-C
  // to be a legal character to send when in interactive mode.
  setvect( 0x23, ctrlCHandler);

  TcpSocket *mySocket;
  int8_t rc;
  
  fprintf( stderr, "Waiting for a connection on port %u. Press [ESC] to abort.\n\n", LclPort );

  TcpSocket *listeningSocket = TcpSocketMgr::getSocket( );
  listeningSocket->listen( LclPort, RECV_BUFFER_SIZE );

  // Listen is non-blocking.  Need to wait
  while ( 1 ) {
    if ( CtrlBreakDetected ) {
      rc = -1;
      break;
    }

    PACKET_PROCESS_SINGLE;
    Arp::driveArp( );
    Tcp::drivePackets( );

    mySocket = TcpSocketMgr::accept( );
    if ( mySocket != NULL ) {
      listeningSocket->close( );
      TcpSocketMgr::freeSocket( listeningSocket );
      rc = 0;
      break;
    }

    if ( _bios_keybrd(1) != 0 ) {
      char c = _bios_keybrd(0);

      if ( (c == 27) || (c == 3) ) {
        rc = -1;
        break;
      }
    }
  }

  if ( rc != 0 ) {
    fprintf( stderr, "Socket open failed\n" );
    shutdown( -1 );
  }

  fprintf( stderr, "Connection received from %d.%d.%d.%d:%u\n\n",
            mySocket->dstHost[0], mySocket->dstHost[1],
            mySocket->dstHost[2], mySocket->dstHost[3],
            mySocket->dstPort );

  uint8_t done = 0;

  while ( !done ) {
    if ( CtrlBreakDetected ) {
      fprintf( stderr, "\nCtrl-Break detected\n" );
      done = 1;
    }

    // Service the connection
    PACKET_PROCESS_SINGLE;
    Arp::driveArp( );
    Tcp::drivePackets( );

    if ( mySocket->isRemoteClosed( ) ) {
      done = 1;
    }

    // Process incoming packets first.

    int16_t recvRc = mySocket->recv( recvBuffer, RECV_BUFFER_SIZE );

    if ( recvRc > 0 ) {
      write( 1, recvBuffer, recvRc );
    }
    else if ( recvRc < 0 ) {
      fprintf( stderr, "\nError reading from socket\n" );
      done = 1;
    }

    if ( _bios_keybrd(1) ) {
      uint16_t key = _bios_keybrd(0);
      char ch = key & 0xff;

      if ( ch == 0 ) {
        uint8_t ekey = key >> 8;

        if ( ekey == 45 ) { // Alt-X
          done = 1;
        }
        else if ( ekey == 35 ) { // Alt-H
          fprintf( stderr, "\nSample: Press Alt-X to exit\n\n" );
        }

      }
      else {
        int8_t sendRc = mySocket->send( (uint8_t *)&ch, 1 );
        // Should check the return code, but we'll leave that
        // as an exercise to the interested student.
      }
    }
  }

  mySocket->close( );

  TcpSocketMgr::freeSocket( mySocket );

  shutdown( 0 );

  return 0;
}

char *HelpText[] = {
  "\nUsage: jrecv -port <port>\n",
  "<port> port on which to listen for incoming connections\n",
  NULL
};

void usage( void ) {
  uint8_t i=0;
  while ( HelpText[i] != NULL ) {
    fprintf( stderr, HelpText[i] );
    i++;
  }
  exit( 1 );
}

void errorMsg( char *msg ) {
  fprintf( stderr, msg );
  usage( );
}

static void parseArgs( int argc, char *argv[] ) {
  int i=1;
  for ( ; i<argc; i++ ) {

    if ( stricmp( argv[i], "-help" ) == 0 ) {
      usage( );
    }
    else if ( stricmp( argv[i], "-port" ) == 0 ) {

      i++;
      if ( i == argc ) {
        errorMsg( "Need to specify a port to listen on\n" );
      }

      LclPort = atoi( argv[i] );

      if ( LclPort == 0 ) {
        errorMsg( "Use a non-zero port to listen on\n" );
      }
    }
    else {
      fprintf( stderr, "Unknown option %s\n", argv[i] );
      usage( );
    }
  }
}

static void shutdown( int rc ) {
  setvect( 0x1b, oldCtrlBreakHandler);

  Utils::endStack( );
  Utils::dumpStats( stderr );
  fclose( TrcStream );
  exit( rc );
}


