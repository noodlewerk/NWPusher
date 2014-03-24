//
//  NWSSLConnection.m
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWSSLConnection.h"
#import "NWSecTools.h"
#include <netdb.h>


OSStatus NWSSLRead(SSLConnectionRef connection, void *data, size_t *length);
OSStatus NWSSLWrite(SSLConnectionRef connection, const void *data, size_t *length);


@implementation NWSSLConnection {
    int _socket;
    SSLContextRef _context;
}

- (instancetype)init
{
    return [self initWithHost:nil port:0 identity:nil];
}

- (instancetype)initWithHost:(NSString *)host port:(NSUInteger)port identity:(NWIdentityRef)identity
{
    self = [super init];
    if (self) {
        _host = host;
        _port = port;
        _identity = identity;
        _socket = -1;
    }
    return self;
}

- (void)dealloc
{
    [self disconnect];
}

- (NWError)connect
{
    [self disconnect];
    NWError socket = [self connectSocket];
    if (socket != kNWSuccess) {
        [self disconnect];
        return socket;
    }
    NWError ssl = [self connectSSL];
    if (ssl != kNWSuccess) {
        [self disconnect];
        return ssl;
    }
    NWError handshake = [self handshakeSSL];
    if (handshake != kNWSuccess) {
        [self disconnect];
        return handshake;
    }
    return kNWSuccess;
}

- (NWError)connectSocket
{
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        return kNWErrorSocketCreate;
    }
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(struct sockaddr_in));
    struct hostent *entr = gethostbyname(_host.UTF8String);
    if (!entr) {
        return kNWErrorSocketResolveHostName;
    }
    struct in_addr host;
    memcpy(&host, entr->h_addr, sizeof(struct in_addr));
    addr.sin_addr = host;
    addr.sin_port = htons((u_short)_port);
    addr.sin_family = AF_INET;
    int conn = connect(sock, (struct sockaddr *)&addr, sizeof(struct sockaddr_in));
    if (conn < 0) {
        return kNWErrorSocketConnect;
    }
    int cntl = fcntl(sock, F_SETFL, O_NONBLOCK);
    if (cntl < 0) {
        return kNWErrorSocketFileControl;
    }
    int set = 1, sopt = setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(int));
    if (sopt < 0) {
        return kNWErrorSocketOptions;
    }
    _socket = sock;
    return kNWSuccess;
}

- (NWError)connectSSL
{
    SSLContextRef context = SSLCreateContext(NULL, kSSLClientSide, kSSLStreamType);
    if (!context) {
        return kNWErrorSSLContext;
    }
    OSStatus setio = SSLSetIOFuncs(context, NWSSLRead, NWSSLWrite);
    if (setio != errSecSuccess) {
        return kNWErrorSSLIOFuncs;
    }
    OSStatus setconn = SSLSetConnection(context, (SSLConnectionRef)(NSInteger)_socket);
    if (setconn != errSecSuccess) {
        return kNWErrorSSLConnection;
    }
    OSStatus setpeer = SSLSetPeerDomainName(context, _host.UTF8String, strlen(_host.UTF8String));
    if (setpeer != errSecSuccess) {
        return kNWErrorSSLPeerDomainName;
    }
    OSStatus setcert = SSLSetCertificate(context, (__bridge CFArrayRef)@[_identity]);
    if (setcert != errSecSuccess) {
        return kNWErrorSSLCertificate;
    }
    _context = context;
    return kNWSuccess;
}

- (NWError)handshakeSSL
{
    OSStatus status = errSSLWouldBlock;
    for (NSUInteger i = 0; i < 1 << 26 && status == errSSLWouldBlock; i++) {
        status = SSLHandshake(_context);
    }
    switch (status) {
        case errSecSuccess: return kNWSuccess;
        case errSSLWouldBlock: return kNWErrorSSLHandshakeTimeout;
        case errSecIO: return kNWErrorSSLDroppedByServer;
        case errSecAuthFailed: return kNWErrorSSLAuthFailed;
    }
    return kNWErrorSSLHandshakeFail;
}

- (NWError)read:(NSMutableData *)data length:(NSUInteger *)length
{
    *length = 0;
    size_t processed = 0;
    OSStatus status = SSLRead(_context, data.mutableBytes, data.length, &processed);
    *length = processed;
    switch (status) {
        case errSecSuccess: return kNWSuccess;
        case errSSLWouldBlock: return kNWSuccess;
        case errSecIO: return kNWErrorReadDroppedByServer;
        case errSSLClosedAbort: return kNWErrorReadClosedAbort;
        case errSSLClosedGraceful: return kNWErrorReadClosedGraceful;
    }
    return kNWErrorReadFail;
}

- (NWError)write:(NSData *)data length:(NSUInteger *)length
{
    *length = 0;
    size_t processed = 0;
    OSStatus status = SSLWrite(_context, data.bytes, data.length, &processed);
    *length = processed;
    switch (status) {
        case errSecSuccess: return kNWSuccess;
        case errSSLWouldBlock: return kNWSuccess;
        case errSecIO: return kNWErrorWriteDroppedByServer;
        case errSSLClosedAbort: return kNWErrorWriteClosedAbort;
        case errSSLClosedGraceful: return kNWErrorWriteClosedGraceful;
    }
    return kNWErrorWriteFail;
}

- (void)disconnect
{
    if (_context) SSLClose(_context);
    if (_socket >= 0) close(_socket); _socket = -1;
    if (_context) CFRelease(_context); _context = NULL;
}

#pragma mark - Deprecated

- (SecCertificateRef)certificate
{
    NWCertificateRef result = nil;
    [NWSecTools certificateWithIdentity:_identity certificate:&result];
    return (SecCertificateRef)CFBridgingRetain(result);
}

- (NWError)reconnect
{
    return [self connect];
}

@end

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
    if (rcvd > 0 || !leng) {
        return errSecSuccess;
    }
    if (!rcvd) {
        return errSSLClosedGraceful;
    }
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
    if (wrtn > 0 || !leng) {
        return errSecSuccess;
    }
    switch (errno) {
        case EAGAIN: return errSSLWouldBlock;
        case EPIPE: return errSSLClosedAbort;
    }
    return errSecIO;
}
