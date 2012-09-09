//
//  NWSSLConnection.m
//  Pusher
//
//  Created by Leo on 9/9/12.
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWSSLConnection.h"
#import "ioSock.h"
#include <sys/socket.h>

@implementation NWSSLConnection {
    otSocket connection;
    SSLContextRef context;
}

@synthesize host, port, identity;

- (id)initWithHost:(NSString *)_host port:(NSUInteger)_port identity:(SecIdentityRef)_identity
{
    self = [super init];
    if (self) {
        host = _host;
        port = _port;
        identity = _identity;
        CFRetain(identity);
    }
    return self;
}

- (void)dealloc
{
    [self disconnect];
    if (identity) CFRelease(identity); identity = NULL;
}

- (BOOL)connect
{
    PeerSpec spec;
    OSStatus status = MakeServerConnection(host.UTF8String, (int)port, &connection, &spec);
    if (status != noErr) {
        NWLogWarn(@"Unable to create connection to server (%i)", status);
        return NO;
    }
    
    status = SSLNewContext(false, &context);
    if (status != noErr) {
        NWLogWarn(@"Unable create SSL context (%i)", status);
        return NO;
    }
    
    status = SSLSetIOFuncs(context, SocketRead, SocketWrite);
    if (status != noErr) {
        NWLogWarn(@"Unable to set socket callbacks (%i)", status);
        return NO;
    }
    
    status = SSLSetConnection(context, connection);
    if (status != noErr) {
        NWLogWarn(@"Unable to set SSL connection (%i)", status);
        return NO;
    }
    
    status = SSLSetPeerDomainName(context, host.UTF8String, strlen(host.UTF8String));
    if (status != noErr) {
        NWLogWarn(@"Unable to set peer domain (%i)", status);
        return NO;
    }
    
    CFArrayRef certificates = CFArrayCreate(NULL, (const void **)&identity, 1, NULL);
    status = SSLSetCertificate(context, certificates);
    CFRelease(certificates);
    if (status != noErr) {
        NWLogWarn(@"Unable to assign certificate (%i)", status);
        return NO;
    }
    
    do {
        status = SSLHandshake(context);
    } while(status == errSSLWouldBlock);
    if (status != noErr) {
        switch (status) {
            case ioErr: NWLogWarn(@"Unable to perform SSL handshake, no connection"); break;
            case errSecAuthFailed: NWLogWarn(@"Unable to perform SSL handshake, authentication failed"); break;
            default: NWLogWarn(@"Unable to perform SSL handshake (%i)", status); break;
        }
        return NO;
    }
    
    int set = 1;
    setsockopt((int)connection, SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(int));
    
    return YES;
}

- (BOOL)read:(NSMutableData *)data length:(NSUInteger *)length
{
    size_t processed = 0;
    void *bytes = data.mutableBytes;
    OSStatus status = errSSLWouldBlock;
    for (NSUInteger i = 0; i < 4 && status == errSSLWouldBlock; i++) {
        status = SSLRead(context, bytes, data.length, &processed);
    }
    if (status != noErr && status != errSSLWouldBlock) {
        switch (status) {
            case ioErr: NWLogWarn(@"Failed to read, connection dropped by server"); break;
            case errSSLClosedAbort: NWLogWarn(@"Failed to read, connection error"); break;
            case errSSLClosedGraceful: NWLogWarn(@"Failed to read, connection closed"); break;
            default: NWLogWarn(@"Failed to read (%i %zu)", status, processed); break;
        }
        return NO;
    }
    
    if (length) *length = processed;
    return YES;
}

- (BOOL)write:(NSData *)data length:(NSUInteger *)length
{
    size_t processed = 0;
    const void *bytes = data.bytes;
    OSStatus status = errSSLWouldBlock;
    for (NSUInteger i = 0; i < 4 && status == errSSLWouldBlock; i++) {
        status = SSLWrite(context, bytes, data.length, &processed);
    }
    if (status != noErr && status != errSSLWouldBlock) {
        switch (status) {
            case ioErr: NWLogWarn(@"Failed to write, connection dropped by server"); break;
            case errSSLClosedAbort: NWLogWarn(@"Failed to write, connection error"); break;
            case errSSLClosedGraceful: NWLogWarn(@"Failed to write, connection closed"); break;
            default: NWLogWarn(@"Failed to write (%i %zu)", status, processed); break;
        }
        return NO;
    }
    
    if (length) *length = processed;
    return YES;
}

- (void)disconnect
{
    SSLClose(context);
    close((int)connection); connection = NULL;
    SSLDisposeContext(context);    context = NULL;
}

@end
