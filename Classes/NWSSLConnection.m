//
//  NWSSLConnection.m
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWSSLConnection.h"
#import "ioSock.h"
#include <sys/socket.h>


@implementation NWSSLConnection {
    otSocket _connection;
    SSLContextRef _context;
}

- (id)initWithHost:(NSString *)host port:(NSUInteger)port identity:(SecIdentityRef)identity
{
    self = [super init];
    if (self) {
        _host = host;
        _port = port;
        _identity = identity;
        CFRetain(identity);
    }
    return self;
}

- (void)dealloc
{
    [self disconnect];
    if (_identity) CFRelease(_identity); _identity = NULL;
}

- (NWPusherResult)connect
{
    PeerSpec spec;
    OSStatus status = MakeServerConnection(_host.UTF8String, (int)_port, &_connection, &spec);
    if (status != noErr) {
        [self disconnect];
        return kNWPusherResultIOConnectFailed;
    }
    
    _context = SSLCreateContext(NULL, kSSLClientSide, kSSLStreamType);
    if (!_context) {
        [self disconnect];
        return kNWPusherResultIOConnectSSLContext;
    }
    
    status = SSLSetIOFuncs(_context, SocketRead, SocketWrite);
    if (status != noErr) {
        [self disconnect];
        return kNWPusherResultIOConnectSocketCallbacks;
    }
    
    status = SSLSetConnection(_context, _connection);
    if (status != noErr) {
        [self disconnect];
        return kNWPusherResultIOConnectSSL;
    }
    
    status = SSLSetPeerDomainName(_context, _host.UTF8String, strlen(_host.UTF8String));
    if (status != noErr) {
        [self disconnect];
        return kNWPusherResultIOConnectPeerDomain;
    }
    
    CFArrayRef certificates = CFArrayCreate(NULL, (const void **)&_identity, 1, NULL);
    status = SSLSetCertificate(_context, certificates);
    CFRelease(certificates);
    if (status != noErr) {
        [self disconnect];
        return kNWPusherResultIOConnectAssignCertificate;
    }
    
    status = errSSLWouldBlock;
    for (NSUInteger i = 0; i < 4 && status == errSSLWouldBlock; i++) {
        status = SSLHandshake(_context);
    }
    if (status != noErr) {
        [self disconnect];
        switch (status) {
            case ioErr: return kNWPusherResultIOConnectSSLHandshakeConnection;
            case errSecAuthFailed: return kNWPusherResultIOConnectSSLHandshakeAuthentication;
            case errSSLWouldBlock: return kNWPusherResultIOConnectTimeout;
        }
        return kNWPusherResultIOConnectSSLHandshakeError;
    }
    
    int set = 1;
    setsockopt((int)_connection, SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(int));
    
    return kNWPusherResultSuccess;
}

- (NWPusherResult)read:(NSMutableData *)data length:(NSUInteger *)length
{
    size_t processed = 0;
    void *bytes = data.mutableBytes;
    OSStatus status = errSSLWouldBlock;
    for (NSUInteger i = 0; i < 4 && status == errSSLWouldBlock; i++) {
        status = SSLRead(_context, bytes, data.length, &processed);
    }
    if (status != noErr && status != errSSLWouldBlock) {
        switch (status) {
            case ioErr: return kNWPusherResultIOReadDroppedByServer;
            case errSSLClosedAbort: return kNWPusherResultIOReadConnectionError;
            case errSSLClosedGraceful: return kNWPusherResultIOReadConnectionClosed;
        }
        return kNWPusherResultIOReadError;
    }
    
    if (length) *length = processed;
    return kNWPusherResultSuccess;
}

- (NWPusherResult)write:(NSData *)data length:(NSUInteger *)length
{
    size_t processed = 0;
    const void *bytes = data.bytes;
    OSStatus status = errSSLWouldBlock;
    for (NSUInteger i = 0; i < 4 && status == errSSLWouldBlock; i++) {
        status = SSLWrite(_context, bytes, data.length, &processed);
    }
    if (status != noErr && status != errSSLWouldBlock) {
        switch (status) {
            case ioErr: return kNWPusherResultIOWriteDroppedByServer;
            case errSSLClosedAbort: return kNWPusherResultIOWriteConnectionError;
            case errSSLClosedGraceful: return kNWPusherResultIOWriteConnectionClosed;
        }
        return kNWPusherResultIOWriteError;
    }
    
    if (length) *length = processed;
    return kNWPusherResultSuccess;
}

- (NWPusherResult)reconnect
{
    [self disconnect];
    return [self connect];
}

- (void)disconnect
{
    if (_context) SSLClose(_context);
    if (_connection) close((int)_connection); _connection = NULL;
    if (_context) CFRelease(_context); _context = NULL;
}

- (SecCertificateRef)certificate
{
    SecCertificateRef result = NULL;
    OSStatus status = SecIdentityCopyCertificate(_identity, &result);
    if (status != noErr) return nil;
    return result;
}

@end
