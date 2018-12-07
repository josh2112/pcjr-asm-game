
#include <bios.h>
#include <dos.h>
#include <io.h>
#include <fcntl.h>
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

uint16_t WRITE_BUF_SIZE = 8192;  // Size of buffer used for writing stdout

// Trap Ctrl-Break and Ctrl-C so that we can unhook the timer interrupt
// and shutdown cleanly.

// Check this flag once in a while to see if the user wants out.
volatile uint8_t CtrlBreakDetected = 0;

void ( __interrupt __far *oldCtrlBreakHandler )();

void __interrupt __far ctrlBreakHandler( ) { CtrlBreakDetected = 1; }

void __interrupt __far ctrlCHandler( ) {}

int main( int argc, char *argv[] ) {
  fprintf( stderr, "JRECV v0.1 (c) 2018 Joshua Foster\n\n" );

  // Read command line arguments
  parseArgs( argc, argv );

  // Setup mTCP environment
  if( Utils::parseEnv() != 0 ) exit(-1);

  // Initialize TCP/IP stack
  if( Utils::initStack( 2, TCP_SOCKET_RING_SIZE ) ) {
    fprintf( stderr, "\nFailed to initialize TCP/IP - exiting\n" );
    exit( -1 );
  }

  uint8_t *fileWriteBuffer = (uint8_t *)malloc( WRITE_BUF_SIZE );

  // From this point forward you have to call the shutdown() routine to
  // exit because we have the timer interrupt hooked.

  // Save off the oldCtrlBreakHander and put our own in.  Shutdown() will
  // restore the original handler for us.
  oldCtrlBreakHandler = getvect( 0x1b );
  setvect( 0x1b, ctrlBreakHandler );

  // Get the Ctrl-C interrupt too, but do nothing.  We actually want Ctrl-C
  // to be a legal character to send when in interactive mode.
  setvect( 0x23, ctrlCHandler );

  setmode( 1, O_BINARY );

  TcpSocket *mySocket;
  int8_t rc;
  
  fprintf( stderr, "Waiting for a connection on port %u. Press [ESC] to abort.\n\n", LclPort );

  TcpSocket *listeningSocket = TcpSocketMgr::getSocket();
  listeningSocket->listen( LclPort, RECV_BUFFER_SIZE );

  // Listen is non-blocking.  Need to wait
  while( 1 ) {
    if( CtrlBreakDetected ) {
      rc = -1;
      break;
    }

    PACKET_PROCESS_SINGLE;
    Arp::driveArp();
    Tcp::drivePackets();

    mySocket = TcpSocketMgr::accept();
    if( mySocket != NULL ) {
      listeningSocket->close();
      TcpSocketMgr::freeSocket( listeningSocket );
      rc = 0;
      break;
    }

    if( _bios_keybrd(1) != 0 ) {
      char c = _bios_keybrd(0);

      if( (c == 27) || (c == 3) ) {
        rc = -1;
        break;
      }
    }
  }

  if( rc != 0 ) {
    fprintf( stderr, "Socket open failed\n" );
    shutdown( -1 );
  }

  fprintf( stderr, "Connection received from %d.%d.%d.%d:%u\n\n",
            mySocket->dstHost[0], mySocket->dstHost[1],
            mySocket->dstHost[2], mySocket->dstHost[3],
            mySocket->dstPort );

  uint8_t done = 0;
  uint16_t bytesRead = 0;
  uint16_t bytesToRead = WRITE_BUF_SIZE; // Bytes to read from socket

  while( !done ) {
    if( CtrlBreakDetected ) {
      fprintf( stderr, "\nCtrl-Break detected\n" );
      done = 1;
    }

    // Service the connection
    PACKET_PROCESS_SINGLE;
    Arp::driveArp();
    Tcp::drivePackets();

    if ( mySocket->isRemoteClosed( ) ) done = 1;
    
    uint8_t *packet;

    while ( packet = ((uint8_t *)mySocket->incoming.dequeue( )) ) {
      IpHeader *ip = (IpHeader *)(packet + sizeof(EthHeader) );
      TcpHeader *tcp = (TcpHeader *)(ip->payloadPtr( ));
      uint8_t *userData = ((uint8_t *)tcp)+tcp->getTcpHlen( );
      uint16_t len = ip->payloadLen( ) - tcp->getTcpHlen( );

      // Copy to our filebuffer.  If we are close to the end of
      // the file buffer, write it out.

      memcpy( fileWriteBuffer+bytesRead, userData, len );
      bytesRead += len;

      // Get rid of the incoming buffer as soon as possible.
      Buffer_free( packet );

      if( (WRITE_BUF_SIZE - bytesRead) < MyMTU ) {
        if( write( 1, fileWriteBuffer, bytesRead ) != bytesRead ) {
          fprintf( stderr, "\nwrite() failed!" );
          break;
        }
        bytesRead = 0;
      }
    }

    if( _bios_keybrd(1) ) {
      uint16_t key = _bios_keybrd(0);
      char ch = key & 0xff;

      if ( ch == 0 ) {
        uint8_t ekey = key >> 8;

        if ( ekey == 45 ) { // Alt-X
          done = 1;
        }
        else if ( ekey == 35 ) { // Alt-H
          fprintf( stderr, "\JRECV: Press Alt-X to exit\n\n" );
        }
      }
    }
  }

  mySocket->close();

  TcpSocketMgr::freeSocket( mySocket );

  shutdown( 0 );

  return 0;
}

void usage( void ) {
  fprintf( stderr, "Usage: jrecv -port <port>\n" \
  "<port> port on which to listen for incoming connections\n" );
  exit( 1 );
}

void errorMsg( char *msg ) {
  fprintf( stderr, msg );
  usage();
}

static void parseArgs( int argc, char *argv[] ) {
  int i=1;
  for ( ; i<argc; i++ ) {

    if ( stricmp( argv[i], "-help" ) == 0 ) {
      usage();
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
      usage();
    }
  }
}

static void shutdown( int rc ) {
  setvect( 0x1b, oldCtrlBreakHandler );

  Utils::endStack( );
  Utils::dumpStats( stderr );
  fclose( TrcStream );
  exit( rc );
}


