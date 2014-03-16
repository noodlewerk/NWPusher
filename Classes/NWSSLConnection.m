//
//  NWSSLConnection.m
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWSSLConnection.h"
#include <netdb.h>


OSStatus NWSSLConnect(const char *host, int port, SSLConnectionRef *connection);
OSStatus NWSSLRead(SSLConnectionRef connection, void *data, size_t *length);
OSStatus NWSSLWrite(SSLConnectionRef connection, const void *data, size_t *length);
OSStatus NWSSLClose(SSLConnectionRef connection);


@implementation NWSSLConnection {
    SSLConnectionRef _connection;
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
    OSStatus status = NWSSLConnect(_host.UTF8String, (int)_port, &_connection);
    if (status != errSecSuccess) {
        [self disconnect];
        return kNWPusherResultIOConnectFailed;
    }
    
    _context = SSLCreateContext(NULL, kSSLClientSide, kSSLStreamType);
    if (!_context) {
        [self disconnect];
        return kNWPusherResultIOConnectSSLContext;
    }
    
    status = SSLSetIOFuncs(_context, NWSSLRead, NWSSLWrite);
    if (status != errSecSuccess) {
        [self disconnect];
        return kNWPusherResultIOConnectSocketCallbacks;
    }
    
    status = SSLSetConnection(_context, (SSLConnectionRef)(NSInteger)_connection);
    if (status != errSecSuccess) {
        [self disconnect];
        return kNWPusherResultIOConnectSSL;
    }
    
    status = SSLSetPeerDomainName(_context, _host.UTF8String, strlen(_host.UTF8String));
    if (status != errSecSuccess) {
        [self disconnect];
        return kNWPusherResultIOConnectPeerDomain;
    }
    
    CFArrayRef certificates = CFArrayCreate(NULL, (const void **)&_identity, 1, NULL);
    status = SSLSetCertificate(_context, certificates);
    CFRelease(certificates);
    if (status != errSecSuccess) {
        [self disconnect];
        return kNWPusherResultIOConnectAssignCertificate;
    }
    
    status = errSSLWouldBlock;
    for (NSUInteger i = 0; i < 1 << 26 && status == errSSLWouldBlock; i++) {
        status = SSLHandshake(_context);
    }
    if (status != errSecSuccess) {
        [self disconnect];
        switch (status) {
            case errSecIO: return kNWPusherResultIOConnectSSLHandshakeConnection;
            case errSecAuthFailed: return kNWPusherResultIOConnectSSLHandshakeAuthentication;
            case errSSLWouldBlock: return kNWPusherResultIOConnectTimeout;
        }
        return kNWPusherResultIOConnectSSLHandshakeError;
    }
    
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
    if (status != errSecSuccess && status != errSSLWouldBlock) {
        switch (status) {
            case errSecIO: return kNWPusherResultIOReadDroppedByServer;
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
    if (status != errSecSuccess && status != errSSLWouldBlock) {
        switch (status) {
            case errSecIO: return kNWPusherResultIOWriteDroppedByServer;
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
    if (_connection) NWSSLClose(_connection); _connection = NULL;
    if (_context) CFRelease(_context); _context = NULL;
}

- (SecCertificateRef)certificate
{
    SecCertificateRef result = NULL;
    OSStatus status = SecIdentityCopyCertificate(_identity, &result);
    if (status != errSecSuccess) return nil;
    return result;
}

@end


OSStatus NWSSLConnect(const char *hostName, int port, SSLConnectionRef *connection) {
    *connection = 0;
    struct hostent *entr = gethostbyname(hostName);
    if (!entr) return errSecIO;
    struct in_addr host;
    memcpy(&host, entr->h_addr, sizeof(struct in_addr));
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in addr;
    addr.sin_addr = host;
    addr.sin_port = htons((u_short)port);
    addr.sin_family = AF_INET;
    int conn = connect(sock, (struct sockaddr *) &addr, sizeof(struct sockaddr_in));
    if (conn < 0) return errSecIO;
    int cntl = fcntl(sock, F_SETFL, O_NONBLOCK);
    if (cntl < 0) return errSecIO;
    int set = 1;
    setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(int));
    *connection = (SSLConnectionRef)(long)sock;
    return errSecSuccess;
}

OSStatus NWSSLRead(SSLConnectionRef connection, void *data, size_t *length) {
    size_t leng = *length;
    *length = 0;
    size_t read = 0;
    ssize_t rcvd = 0;
    for(; read < leng; read += rcvd) {
        rcvd = recv((int)connection, (char *)data + read, leng - read, 0);
        if (rcvd <= 0) break;
    }
    *length = read;
    if (rcvd > 0) return errSecSuccess;
    if (!rcvd) return errSSLClosedGraceful;
    switch (errno) {
        case EAGAIN: return errSSLWouldBlock;
        case ECONNRESET: return errSSLClosedAbort;
    }
    return errSecIO;
}

OSStatus NWSSLWrite(SSLConnectionRef connection, const void *data, size_t *length) {
    size_t leng = *length;
    *length = 0;
    size_t sent = 0;
    ssize_t wrtn = 0;
    for (; sent < leng; sent += wrtn) {
        wrtn = write((int)connection, (char *)data + sent, leng - sent);
        if (wrtn <= 0) break;
    }
    *length = sent;
    if (wrtn > 0) return errSecSuccess;
    switch (errno) {
        case EAGAIN: return errSSLWouldBlock;
        case EPIPE: return errSSLClosedAbort;
    }
    return errSecIO;
}

OSStatus NWSSLClose(SSLConnectionRef connection) {
    ssize_t clsd = close((int)connection);
    if (clsd < 0) return errSecIO;
    return errSecSuccess;
}
