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
 * ioSock.h - socket-based I/O routines for use with Secure Transport
 */

#ifndef	_IO_SOCK_H_
#define _IO_SOCK_H_

#include <Security/SecureTransport.h>
#include <sys/types.h>

#ifdef	__cplusplus
extern "C" {
#endif

/*
 * Opaque reference to an Open Transport connection.
 */
typedef int otSocket;

/*
 * info about a peer returned from MakeServerConnection() and
 * AcceptClientConnection().
 */
typedef struct
{   UInt32      ipAddr;
    int         port;
} PeerSpec;

/*
 * Ont-time only init.
 */
void initSslOt(void);

/*
 * Connect to server.
 */
extern OSStatus MakeServerConnection(
	const char *hostName,
	int port,
	int nonBlocking,		// 0 or 1
	otSocket *socketNo, 	// RETURNED
	PeerSpec *peer);		// RETURNED

/*
 * Set up an otSocket to listen for client connections. Call once, then
 * use multiple AcceptClientConnection calls.
 */
OSStatus ListenForClients(
	int port,
	int nonBlocking,		// 0 or 1
	otSocket *socketNo); 	// RETURNED

/*
 * Accept a client connection. Call endpointShutdown() for each successful;
 * return from this function.
 */
OSStatus AcceptClientConnection(
	otSocket listenSock, 		// obtained from ListenForClients
	otSocket *acceptSock, 		// RETURNED
	PeerSpec *peer);			// RETURNED

/*
 * Shut down a connection.
 */
void endpointShutdown(
	otSocket socket);

/*
 * R/W. Called out from SSL.
 */
OSStatus SocketRead(
	SSLConnectionRef 	connection,
	void 				*data, 			/* owned by
	 									 * caller, data
	 									 * RETURNED */
	size_t 				*dataLength);	/* IN/OUT */

OSStatus SocketWrite(
	SSLConnectionRef 	connection,
	const void	 		*data,
	size_t 				*dataLength);	/* IN/OUT */

#ifdef	__cplusplus
}
#endif

#endif	/* _IO_SOCK_H_ */
