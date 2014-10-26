//
//  NWSSLConnection.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>


/** Provides an interface to the SSL connection with APNS. `NWIdentityRef` represents a `SecIdentityRef`. Methods return `nil` or `NO` if an error occurred.
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

// deprecated

- (NWError)connect __deprecated;
- (NWError)read:(NSMutableData *)data length:(NSUInteger *)length __deprecated;
- (NWError)write:(NSData *)data length:(NSUInteger *)length __deprecated;

@end
