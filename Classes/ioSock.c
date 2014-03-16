/*
 * Copyright (c) 2006-2008,2010-2012 Apple Inc. All Rights Reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_LICENSE_HEADER_END@
 */

/*
 * ioSock.c - socket-based I/O routines for use with Secure Transport
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

#include <Security/SecBase.h>
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

/* indicate errSSLWouldBlock with a '.' */
#define SSL_DISPL_WOULD_BLOCK	0

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
	printf("%s(%u): moved (%u) bytes\n", str, (unsigned)req, (unsigned)act);
	#if	SSL_OT_IO_DUMP
	{
		unsigned i;
		
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
void initSslOt(void)
{

}

/*
 * Connect to server. 
 */
#define GETHOST_RETRIES		3

OSStatus MakeServerConnection(
	const char *hostName, 
	int port, 
	int nonBlocking,		// 0 or 1
	otSocket *socketNo, 	// RETURNED
	PeerSpec *peer)			// RETURNED
{
    struct sockaddr_in  addr;
	struct hostent      *ent;
    struct in_addr      host;
	int					sock = 0;
	
	*socketNo = 0;
    if (hostName[0] >= '0' && hostName[0] <= '9')
    {
        host.s_addr = inet_addr(hostName);
    }
    else {
		unsigned dex;
		/* seeing a lot of soft failures here that I really don't want to track down */
		for(dex=0; dex<GETHOST_RETRIES; dex++) {
			if(dex != 0) {
				printf("\n...retrying gethostbyname(%s)", hostName);
			}
			ent = gethostbyname(hostName);
			if(ent != NULL) {
				break;
			}
		}
        if(ent == NULL) {
			printf("\n***gethostbyname(%s) returned: %s\n", hostName, hstrerror(h_errno));
            return errSecIO;
        }
        memcpy(&host, ent->h_addr, sizeof(struct in_addr));
    }
    sock = socket(AF_INET, SOCK_STREAM, 0);
    addr.sin_addr = host;
    addr.sin_port = htons((u_short)port);

    addr.sin_family = AF_INET;
    if (connect(sock, (struct sockaddr *) &addr, sizeof(struct sockaddr_in)) != 0)
    {   printf("connect returned error\n");
        return errSecIO;
    }

	if(nonBlocking) {
		/* OK to do this after connect? */
		int rtn = fcntl(sock, F_SETFL, O_NONBLOCK);
		if(rtn == -1) {
			perror("fctnl(O_NONBLOCK)");
			return errSecIO;
		}
	}
	
    peer->ipAddr = addr.sin_addr.s_addr;
    peer->port = htons((u_short)port);
	*socketNo = (otSocket)sock;
    return errSecSuccess;
}

/*
 * Set up an otSocket to listen for client connections. Call once, then
 * use multiple AcceptClientConnection calls. 
 */
OSStatus ListenForClients(
	int port, 
	int nonBlocking,		// 0 or 1
	otSocket *socketNo) 	// RETURNED
{  
	struct sockaddr_in  addr;
    struct hostent      *ent;
    int                 len;
	int 				sock;
	
    sock = socket(AF_INET, SOCK_STREAM, 0);
	if(sock < 1) {
		perror("socket");
		return errSecIO;
	}
    
    int reuse = 1;
    int err = setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    if (err != 0) {
        perror("setsockopt");
        return err;
    }
	
    ent = gethostbyname("localhost");
    if (!ent) {
		perror("gethostbyname");
		return errSecIO;
    }
    memcpy(&addr.sin_addr, ent->h_addr, sizeof(struct in_addr));
	
    addr.sin_port = htons((u_short)port);
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_family = AF_INET;
    len = sizeof(struct sockaddr_in);
    if (bind(sock, (struct sockaddr *) &addr, len)) {
		perror("bind");
        return errSecIO;
    }
	if(nonBlocking) {
		int rtn = fcntl(sock, F_SETFL, O_NONBLOCK);
		if(rtn == -1) {
			perror("fctnl(O_NONBLOCK)");
			return errSecIO;
		}
	}

	for(;;) {
		int rtn = listen(sock, 1);
		switch(rtn) {
			case 0:
				*socketNo = (otSocket)sock;
				rtn = errSecSuccess;
				break;
			case EWOULDBLOCK:
				continue;
			default:
				perror("listen");
				rtn = errSecIO;
				break;
		}
		return rtn;
    }
	/* NOT REACHED */
	return 0;
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
    socklen_t           len;
	
    len = sizeof(struct sockaddr_in);
	do {
		sock = accept((int)listenSock, (struct sockaddr *) &addr, &len);
		if (sock < 0) {
			if(errno == EAGAIN) {
				/* nonblocking, no connection yet */
				continue;
			}
			else {
				perror("accept");
				return errSecIO;
			}
		}
		else {
			break;
		}
    } while(1);
	*acceptSock = (otSocket)sock;
    peer->ipAddr = addr.sin_addr.s_addr;
	#if	FORCE_ACCEPT_PEER_PORT_ZERO
	peer->port = 0;
	#else
    peer->port = ntohs(addr.sin_port);
	#endif
    return errSecSuccess;
}

/*
 * Shut down a connection.
 */
void endpointShutdown(
	otSocket sock)
{
	close((int)sock);
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
	int				sock = (int)((long)connection);
	OSStatus		rtn = errSecSuccess;
	UInt32			bytesRead;
	ssize_t			rrtn;
	
	*dataLength = 0;

	for(;;) {
		bytesRead = 0;
		/* paranoid check, ensure errno is getting written */
		errno = -555;
		rrtn = recv(sock, currData, bytesToGo, 0);
		if (rrtn <= 0) {
			if(rrtn == 0) {
				/* closed, EOF */
				rtn = errSSLClosedGraceful;
				break;
			}
			int theErr = errno;
			switch(theErr) {
				case ENOENT:
					/* 
					 * Undocumented but I definitely see this.
					 * Non-blocking sockets only. Definitely retriable
					 * just like an EAGAIN.
					 */
					dprintf(("SocketRead RETRYING on ENOENT, rrtn %d\n",
						(int)rrtn));
					/* normal... */
					//rtn = errSSLWouldBlock;
					/* ...for temp testing.... */
					rtn = errSecIO; 
					break;
				case ECONNRESET:
					/* explicit peer abort */
					rtn = errSSLClosedAbort;
					break;
				case EAGAIN:
					/* nonblocking, no data */
					rtn = errSSLWouldBlock;
					break;
				default:
					dprintf(("SocketRead: read(%u) error %d, rrtn %d\n", 
						(unsigned)bytesToGo, theErr, (int)rrtn));
					rtn = errSecIO;
					break;
			}
			/* in any case, we're done with this call if rrtn <= 0 */
			break;
		}
		bytesRead = (UInt32)rrtn;
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
	#if SSL_DISPL_WOULD_BLOCK
	if(rtn == errSSLWouldBlock) {
		printf("."); fflush(stdout);
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
	size_t		bytesSent = 0;
	int			sock = (int)((long)connection);
	int 		length;
	size_t		dataLen = *dataLength;
	const UInt8 *dataPtr = (UInt8 *)data;
	OSStatus	ortn;
	
	if(oneAtATime && (*dataLength > 1)) {
		size_t i;
		size_t outLen;
		size_t thisMove;
		
		outLen = 0;
		for(i=0; i<dataLen; i++) {
			thisMove = 1;
			ortn = SocketWrite(connection, dataPtr, &thisMove);
			outLen += thisMove;
			dataPtr++;  
			if(ortn) {
				return ortn;
			}
		}
		return errSecSuccess;
	}
	*dataLength = 0;

    do {
        length = (int)write(sock,
				(char*)dataPtr + bytesSent, 
				dataLen - bytesSent);
    } while ((length > 0) && 
			 ( (bytesSent += length) < dataLen) );
	
	if(length <= 0) {
		int theErr = errno;
		switch(theErr) {
			case EAGAIN:
				ortn = errSSLWouldBlock; break;
			case EPIPE:
				ortn = errSSLClosedAbort; break;
			default:
				dprintf(("SocketWrite: write(%u) error %d\n", 
					  (unsigned)(dataLen - bytesSent), theErr));
				ortn = errSecIO;
				break;
		}
	}
	else {
		ortn = errSecSuccess;
	}
	tprintf("SocketWrite", dataLen, bytesSent, dataPtr);
	*dataLength = bytesSent;
	return ortn;
}
