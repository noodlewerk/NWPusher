//
//  NWSSLConnection.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>


/** An SSL (TLS) connection to the APNs.

 This class is basically an Objective-C wrapper around `SSLContextRef` and `SSLConnectionRef`, which are part of the native Secure Transport framework. This class provides a generic interface for SSL (TLS) connections, independent of NWPusher.
 
 A SSL connection is set up using the host name, host port and an identity. The host name will be resolved using DNS. The identity is an instance of `SecIdentityRef` and contains both a certificate and a private key. See the *Secure Transport Reference* for more info on that.
 
 Read more about provider communication in Apple's documentation under *Apple Push Notification Service*.
 
 Methods return `NO` if an error occurred.
 */
@interface NWSSLConnection : NSObject

/** @name Properties */

/** The host name, which will be resolved using DNS. */
@property (nonatomic, strong) NSString *host;

/** The host TCP port number. */
@property (nonatomic, assign) NSUInteger port;

/** Identity containing a certificate-key pair for setting up the TLS connection. */
@property (nonatomic, strong) NWIdentityRef identity;

/** @name Initialization */

/** Initialize a connection parameters host name, port, and identity. */
- (instancetype)initWithHost:(NSString *)host port:(NSUInteger)port identity:(NWIdentityRef)identity;

/** @name Connecting */

/** Connect socket, TLS and perform handshake.
 Can also be used when already connected, which will then first disconnect. */
- (BOOL)connectWithError:(NSError **)error;

/** Drop connection if connected. */
- (void)disconnect;

/** @name I/O */

/** Read length number of bytes into mutable data object. */
- (BOOL)read:(NSMutableData *)data length:(NSUInteger *)length error:(NSError **)error;

/** Write length number of bytes from data object. */
- (BOOL)write:(NSData *)data length:(NSUInteger *)length error:(NSError **)error;

@end
