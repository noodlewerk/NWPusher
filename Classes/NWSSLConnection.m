//
//  NWSSLConnection.m
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWSSLConnection.h"
#include <netdb.h>

#define NWSSL_HANDSHAKE_TRY_COUNT 1 << 26

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

#pragma mark - Connecting

- (BOOL)connectWithError:(NSError *__autoreleasing *)error
{
    [self disconnect];
    BOOL socket = [self connectSocketWithError:error];
    if (!socket) {
        [self disconnect];
        return socket;
    }
    BOOL ssl = [self connectSSLWithError:error];
    if (!ssl) {
        [self disconnect];
        return ssl;
    }
    BOOL handshake = [self handshakeSSLWithError:error];
    if (!handshake) {
        [self disconnect];
        return handshake;
    }
    return YES;
}

- (BOOL)connectSocketWithError:(NSError *__autoreleasing *)error
{
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        return [NWErrorUtil noWithErrorCode:kNWErrorSocketCreate reason:sock error:error];
    }
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(struct sockaddr_in));
    struct hostent *entr = gethostbyname(_host.UTF8String);
    if (!entr) {
        return [NWErrorUtil noWithErrorCode:kNWErrorSocketResolveHostName error:error];
    }
    struct in_addr host;
    memcpy(&host, entr->h_addr, sizeof(struct in_addr));
    addr.sin_addr = host;
    addr.sin_port = htons((u_short)_port);
    addr.sin_family = AF_INET;
    int conn = connect(sock, (struct sockaddr *)&addr, sizeof(struct sockaddr_in));
    if (conn < 0) {
        return [NWErrorUtil noWithErrorCode:kNWErrorSocketConnect reason:conn error:error];
    }
    int cntl = fcntl(sock, F_SETFL, O_NONBLOCK);
    if (cntl < 0) {
        return [NWErrorUtil noWithErrorCode:kNWErrorSocketFileControl reason:cntl error:error];
    }
    int set = 1, sopt = setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(int));
    if (sopt < 0) {
        return [NWErrorUtil noWithErrorCode:kNWErrorSocketOptions reason:sopt error:error];
    }
    _socket = sock;
    return YES;
}

- (BOOL)connectSSLWithError:(NSError *__autoreleasing *)error
{
    SSLContextRef context = SSLCreateContext(NULL, kSSLClientSide, kSSLStreamType);
    if (!context) {
        return [NWErrorUtil noWithErrorCode:kNWErrorSSLContext error:error];
    }
    OSStatus setio = SSLSetIOFuncs(context, NWSSLRead, NWSSLWrite);
    if (setio != errSecSuccess) {
        return [NWErrorUtil noWithErrorCode:kNWErrorSSLIOFuncs reason:setio error:error];
    }
    OSStatus setconn = SSLSetConnection(context, (SSLConnectionRef)(NSInteger)_socket);
    if (setconn != errSecSuccess) {
        return [NWErrorUtil noWithErrorCode:kNWErrorSSLConnection reason:setconn error:error];
    }
    OSStatus setpeer = SSLSetPeerDomainName(context, _host.UTF8String, strlen(_host.UTF8String));
    if (setpeer != errSecSuccess) {
        return [NWErrorUtil noWithErrorCode:kNWErrorSSLPeerDomainName reason:setpeer error:error];
    }
    OSStatus setcert = SSLSetCertificate(context, (__bridge CFArrayRef)@[_identity]);
    if (setcert != errSecSuccess) {
        return [NWErrorUtil noWithErrorCode:kNWErrorSSLCertificate reason:setcert error:error];
    }
    _context = context;
    return YES;
}

- (BOOL)handshakeSSLWithError:(NSError *__autoreleasing *)error
{
    OSStatus status = errSSLWouldBlock;
    for (NSUInteger i = 0; i < NWSSL_HANDSHAKE_TRY_COUNT && status == errSSLWouldBlock; i++) {
        status = SSLHandshake(_context);
    }
    switch (status) {
        case errSecSuccess: return YES;
        case errSSLWouldBlock: return [NWErrorUtil noWithErrorCode:kNWErrorSSLHandshakeTimeout error:error];
        case errSecIO: return [NWErrorUtil noWithErrorCode:kNWErrorSSLDroppedByServer error:error];
        case errSecAuthFailed: return [NWErrorUtil noWithErrorCode:kNWErrorSSLAuthFailed error:error];
        case errSSLUnknownRootCert: return [NWErrorUtil noWithErrorCode:kNWErrorSSLHandshakeUnknownRootCert error:error];
        case errSSLNoRootCert: return [NWErrorUtil noWithErrorCode:kNWErrorSSLHandshakeNoRootCert error:error];
        case errSSLCertExpired: return [NWErrorUtil noWithErrorCode:kNWErrorSSLHandshakeCertExpired error:error];
        case errSSLXCertChainInvalid: return [NWErrorUtil noWithErrorCode:kNWErrorSSLHandshakeXCertChainInvalid error:error];
        case errSSLClientCertRequested: return [NWErrorUtil noWithErrorCode:kNWErrorSSLHandshakeClientCertRequested error:error];
        case errSSLServerAuthCompleted: return [NWErrorUtil noWithErrorCode:kNWErrorSSLHandshakeServerAuthCompleted error:error];
        case errSSLPeerCertExpired: return [NWErrorUtil noWithErrorCode:kNWErrorSSLHandshakePeerCertExpired error:error];
        case errSSLPeerCertRevoked: return [NWErrorUtil noWithErrorCode:kNWErrorSSLHandshakePeerCertRevoked error:error];
        case errSSLPeerCertUnknown: return [NWErrorUtil noWithErrorCode:kNWErrorSSLHandshakePeerCertUnknown error:error];
        case errSSLInternal: return [NWErrorUtil noWithErrorCode:kNWErrorSSLHandshakeInternalError error:error];
#if !TARGET_OS_IPHONE
        case errSecInDarkWake: return [NWErrorUtil noWithErrorCode:kNWErrorSSLInDarkWake error:error];
#endif
        case errSSLClosedAbort: return [NWErrorUtil noWithErrorCode:kNWErrorSSLHandshakeClosedAbort error:error];
    }
    return [NWErrorUtil noWithErrorCode:kNWErrorSSLHandshakeFail reason:status error:error];
}

- (void)disconnect
{
    if (_context) SSLClose(_context);
    if (_socket >= 0) close(_socket); _socket = -1;
    if (_context) CFRelease(_context); _context = NULL;
}

#pragma mark - Read Write

- (BOOL)read:(NSMutableData *)data length:(NSUInteger *)length error:(NSError *__autoreleasing *)error
{
    *length = 0;
    size_t processed = 0;
    OSStatus status = SSLRead(_context, data.mutableBytes, data.length, &processed);
    *length = processed;
    switch (status) {
        case errSecSuccess: return YES;
        case errSSLWouldBlock: return YES;
        case errSecIO: return [NWErrorUtil noWithErrorCode:kNWErrorReadDroppedByServer error:error];
        case errSSLClosedAbort: return [NWErrorUtil noWithErrorCode:kNWErrorReadClosedAbort error:error];
        case errSSLClosedGraceful: return [NWErrorUtil noWithErrorCode:kNWErrorReadClosedGraceful error:error];
    }
    return [NWErrorUtil noWithErrorCode:kNWErrorReadFail reason:status error:error];
}

- (BOOL)write:(NSData *)data length:(NSUInteger *)length error:(NSError *__autoreleasing *)error
{
    *length = 0;
    size_t processed = 0;
    OSStatus status = SSLWrite(_context, data.bytes, data.length, &processed);
    *length = processed;
    switch (status) {
        case errSecSuccess: return YES;
        case errSSLWouldBlock: return YES;
        case errSecIO: return [NWErrorUtil noWithErrorCode:kNWErrorWriteDroppedByServer error:error];
        case errSSLClosedAbort: return [NWErrorUtil noWithErrorCode:kNWErrorWriteClosedAbort error:error];
        case errSSLClosedGraceful: return [NWErrorUtil noWithErrorCode:kNWErrorWriteClosedGraceful error:error];
    }
    return [NWErrorUtil noWithErrorCode:kNWErrorWriteFail reason:status error:error];
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
