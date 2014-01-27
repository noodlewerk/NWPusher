/*
	File:		ioSock.h
        
        Contains:	SecureTransport sample I/O module, X sockets version
        
	Copyright: 	© Copyright 2002 Apple Computer, Inc. All rights reserved.
	
	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
                        ("Apple") in consideration of your agreement to the following terms, and your
                        use, installation, modification or redistribution of this Apple software
                        constitutes acceptance of these terms.  If you do not agree with these terms,
                        please do not use, install, modify or redistribute this Apple software.

                        In consideration of your agreement to abide by the following terms, and subject
                        to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
                        copyrights in this original Apple software (the "Apple Software"), to use,
                        reproduce, modify and redistribute the Apple Software, with or without
                        modifications, in source and/or binary forms; provided that if you redistribute
                        the Apple Software in its entirety and without modifications, you must retain
                        this notice and the following text and disclaimers in all such redistributions of
                        the Apple Software.  Neither the name, trademarks, service marks or logos of
                        Apple Computer, Inc. may be used to endorse or promote products derived from the
                        Apple Software without specific prior written permission from Apple.  Except as
                        expressly stated in this notice, no other rights or licenses, express or implied,
                        are granted by Apple herein, including but not limited to any patent rights that
                        may be infringed by your derivative works or by other works in which the Apple
                        Software may be incorporated.

                        The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
                        WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
                        WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
                        PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
                        COMBINATION WITH YOUR PRODUCTS.

                        IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
                        CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
                        GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
                        ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
                        OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
                        (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
                        ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
				
	Change History (most recent first):
                11/4/02		1.0d1

*/


#include "ioSock.h"
#include <errno.h>
#include <stdio.h>

#include <unistd.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <fcntl.h>

#include <time.h>
#include <strings.h>

/* debugging for this module */
#define SSL_OT_DEBUG		1

/* log errors to stdout */
#define SSL_OT_ERRLOG		1

/* trace all low-level network I/O */
#define SSL_OT_IO_TRACE		0

/* if SSL_OT_IO_TRACE, only log non-zero length transfers */
#define SSL_OT_IO_TRACE_NZ	1

/* pause after each I/O (only meaningful if SSL_OT_IO_TRACE == 1) */
#define SSL_OT_IO_PAUSE		0

/* print a stream of dots while I/O pending */
#define SSL_OT_DOT			1

/* dump some bytes of each I/O (only meaningful if SSL_OT_IO_TRACE == 1) */
#define SSL_OT_IO_DUMP		0
#define SSL_OT_IO_DUMP_SIZE	256

/* general, not-too-verbose debugging */
#if		SSL_OT_DEBUG
#define dprintf(s)	printf s
#else	
#define dprintf(s)
#endif

/* errors --> stdout */
#if		SSL_OT_ERRLOG
#define eprintf(s)	printf s
#else	
#define eprintf(s)
#endif

/* enable nonblocking I/O - maybe should be an arg to MakeServerConnection() */
#define NON_BLOCKING	1

/* trace completion of every r/w */
#if		SSL_OT_IO_TRACE
static void tprintf(
	const char *str, 
	UInt32 req, 
	UInt32 act,
	const UInt8 *buf)	
{
	#if	SSL_OT_IO_TRACE_NZ
	if(act == 0) {
		return;
	}
	#endif
	printf("%s(%d): moved (%d) bytes\n", str, req, act);
	#if	SSL_OT_IO_DUMP
	{
		int i;
		
		for(i=0; i<act; i++) {
			printf("%02X ", buf[i]);
			if(i >= (SSL_OT_IO_DUMP_SIZE - 1)) {
				break;
			}
		}
		printf("\n");
	}
	#endif
	#if SSL_OT_IO_PAUSE
	{
		char instr[20];
		printf("CR to continue: ");
		gets(instr);
	}
	#endif
}

#else	
#define tprintf(str, req, act, buf)
#endif	/* SSL_OT_IO_TRACE */

/*
 * If SSL_OT_DOT, output a '.' every so often while waiting for
 * connection. This gives user a chance to do something else with the
 * UI.
 */

#if	SSL_OT_DOT

static time_t lastTime = (time_t)0;
#define TIME_INTERVAL		3

static void outputDot()
{
	time_t thisTime = time(0);
	
	if((thisTime - lastTime) >= TIME_INTERVAL) {
		printf("."); fflush(stdout);
		lastTime = thisTime;
	}
}
#else
#define outputDot()
#endif


/*
 * One-time only init.
 */
void initSslOt()
{

}

/*
 * Connect to server. 
 */
OSStatus MakeServerConnection(
	const char *hostName, 
	int port, 
	otSocket *socketNo, 	// RETURNED
	PeerSpec *peer)			// RETURNED
{
    struct sockaddr_in  addr;
	struct hostent      *ent;
    struct in_addr      host;
	int					sock = 0;
	
	*socketNo = NULL;
    if (hostName[0] >= '0' && hostName[0] <= '9')
    {
        host.s_addr = inet_addr(hostName);
    }
    else
    {   ent = gethostbyname(hostName);
        if (!ent)
        {   printf("gethostbyname failed\n");
            return ioErr;
        }
        memcpy(&host, ent->h_addr, sizeof(struct in_addr));
    }
    sock = socket(AF_INET, SOCK_STREAM, 0);
    addr.sin_addr = host;
    addr.sin_port = htons((u_short)port);

    addr.sin_family = AF_INET;
    if (connect(sock, (struct sockaddr *) &addr, sizeof(struct sockaddr_in)) != 0)
    {   printf("connect returned error\n");
        return ioErr;
    }

	#if		NON_BLOCKING
	/* OK to do this after connect? */
	{
		int rtn = fcntl(sock, F_SETFL, O_NONBLOCK);
		if(rtn == -1) {
			perror("fctnl(O_NONBLOCK)");
			return ioErr;
		}
	}
	#endif	/* NON_BLOCKING*/
	
    peer->ipAddr = addr.sin_addr.s_addr;
    peer->port = htons((u_short)port);
	*socketNo = (otSocket)(intptr_t)sock;
    return noErr;
}

/*
 * Set up an otSocket to listen for client connections. Call once, then
 * use multiple AcceptClientConnection calls. 
 */
OSStatus ListenForClients(
	int port, 
	otSocket *socketNo) 	// RETURNED
{  
	struct sockaddr_in  addr;
    struct hostent      *ent;
    int                 len;
	int 				sock;
	
    sock = socket(AF_INET, SOCK_STREAM, 0);
	if(sock < 1) {
		perror("socket");
		return ioErr;
	}
	
    ent = gethostbyname("localhost");
    if (!ent) {
		perror("gethostbyname");
		return ioErr;
    }
    memcpy(&addr.sin_addr, ent->h_addr, sizeof(struct in_addr));
	
    addr.sin_port = htons((u_short)port);
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_family = AF_INET;
    len = sizeof(struct sockaddr_in);
    if (bind(sock, (struct sockaddr *) &addr, len)) {
		perror("bind");
		return ioErr;
    }
    if (listen(sock, 1)) {
		perror("listen");
		return ioErr;
    }
	*socketNo = (otSocket)(intptr_t)sock;
    return noErr;
}

/*
 * Accept a client connection.
 */
 
/*
 * Currently we always get back a different peer port number on successive
 * connections, no matter what the client is doing. To test for resumable 
 * session support, force peer port = 0.
 */
#define FORCE_ACCEPT_PEER_PORT_ZERO		1

OSStatus AcceptClientConnection(
	otSocket listenSock, 		// obtained from ListenForClients
	otSocket *acceptSock, 		// RETURNED
	PeerSpec *peer)				// RETURNED
{  
	struct sockaddr_in  addr;
	int					sock;
    socklen_t            len;
	
    len = sizeof(struct sockaddr_in);
    sock = accept((int)listenSock, (struct sockaddr *) &addr, &len);
    if (sock < 0) {
		perror("accept");
		return ioErr;
    }
	*acceptSock = (otSocket)(intptr_t)sock;
    peer->ipAddr = addr.sin_addr.s_addr;
	#if	FORCE_ACCEPT_PEER_PORT_ZERO
	peer->port = 0;
	#else
    peer->port = ntohs(addr.sin_port);
	#endif
    return noErr;
}

/*
 * Shut down a connection.
 */
void endpointShutdown(
	otSocket socket)
{
	close((int)socket);
}
	
/*
 * R/W. Called out from SSL.
 */
OSStatus SocketRead(
	SSLConnectionRef 	connection,
	void 				*data, 			/* owned by 
	 									 * caller, data
	 									 * RETURNED */
	size_t 				*dataLength)	/* IN/OUT */ 
{
	UInt32			bytesToGo = (UInt32)*dataLength;
	UInt32 			initLen = bytesToGo;
	UInt8			*currData = (UInt8 *)data;
	int				sock = (int)connection;
	OSStatus		rtn = noErr;
	UInt32			bytesRead;
	int				rrtn;
	
	*dataLength = 0;

	for(;;) {
		rrtn = (int)read(sock, currData, bytesToGo);
		if (rrtn <= 0) {
			/* this is guesswork... */
			int theErr = errno;
//			dprintf(("SocketRead: read(%d) error %d\n", (int)bytesToGo, theErr));
			#if !NON_BLOCKING
			if((rrtn == 0) && (theErr == 0)) {
				/* try fix for iSync */ 
				rtn = errSSLClosedGraceful;
				//rtn = errSSLClosedAbort;
			}
			else /* do the switch */
			#endif
			switch(theErr) {
				case ENOENT:
					/* connection closed */
					rtn = errSSLClosedGraceful; 
					break;
				case ECONNRESET:
					rtn = errSSLClosedAbort;
					break;
				#if	NON_BLOCKING
				case EAGAIN:
				#else
				case 0:		/* ??? */
				#endif
					rtn = errSSLWouldBlock;
					break;
				default:
					dprintf(("SocketRead: read(%d) error %d\n", 
						(int)bytesToGo, theErr));
					rtn = ioErr;
					break;
			}
			break;
		}
		else {
			bytesRead = rrtn;
		}
		bytesToGo -= bytesRead;
		currData  += bytesRead;
		
		if(bytesToGo == 0) {
			/* filled buffer with incoming data, done */
			break;
		}
	}
	*dataLength = initLen - bytesToGo;
	tprintf("SocketRead", initLen, *dataLength, (UInt8 *)data);
	
	#if SSL_OT_DOT || (SSL_OT_DEBUG && !SSL_OT_IO_TRACE)
	if((rtn == 0) && (*dataLength == 0)) {
		/* keep UI alive */
		outputDot();
	}
	#endif
	return rtn;
}

int oneAtATime = 0;

OSStatus SocketWrite(
	SSLConnectionRef 	connection,
	const void	 		*data, 
	size_t 				*dataLength)	/* IN/OUT */ 
{
	UInt32		bytesSent = 0;
	int			sock = (int)connection;
	int 		length;
	UInt32		dataLen = (UInt32)*dataLength;
	const UInt8 *dataPtr = (UInt8 *)data;
	OSStatus	ortn;
	
	if(oneAtATime && (*dataLength > 1)) {
		UInt32 i;
		UInt32 outLen;
		UInt32 thisMove;
		
		outLen = 0;
		for(i=0; i<dataLen; i++) {
			thisMove = 1;
			ortn = SocketWrite(connection, dataPtr, (size_t *)&thisMove);
			outLen += thisMove;
			dataPtr++;  
			if(ortn) {
				return ortn;
			}
		}
		return noErr;
	}
	*dataLength = 0;

    do {
        length = (int)write(sock,
				(char*)dataPtr + bytesSent, 
				dataLen - bytesSent);
    } while ((length > 0) && 
			 ( (bytesSent += length) < dataLen) );
	
	if(length <= 0) {
		if(errno == EAGAIN) {
			ortn = errSSLWouldBlock;
		}
		else {
			ortn = ioErr;
		}
	}
	else {
		ortn = noErr;
	}
	tprintf("SocketWrite", dataLen, bytesSent, dataPtr);
	*dataLength = bytesSent;
	return ortn;
}
