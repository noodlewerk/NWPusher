//
//  NWType.m
//  Pusher
//
//  Copyright (c) 2014 noodlewerk. All rights reserved.
//

#import "NWType.h"

NSString * const NWErrorReasonCodeKey = @"NWErrorReasonCodeKey";

NSString * descriptionForEnvironentOptions(NWEnvironmentOptions environmentOptions)
{
    switch (environmentOptions) {
        case NWEnvironmentOptionNone: return @"No environment";
        case NWEnvironmentOptionSandbox: return @"Sandbox";
        case NWEnvironmentOptionProduction: return @"Production";
        case NWEnvironmentOptionAny: return @"Sandbox|Production";
    }
    return nil;
}

NSString * descriptionForEnvironent(NWEnvironment environment)
{
    switch (environment) {
        case NWEnvironmentNone: return @"none";
        case NWEnvironmentProduction: return @"production";
        case NWEnvironmentSandbox: return @"sandbox";
        case NWEnvironmentAuto: return @"auto";
    }
    return nil;
}

NSString * descriptionForCertType(NWCertType type)
{
    switch (type) {
        case kNWCertTypeNone: return @"none";
        case kNWCertTypeIOSDevelopment:
        case kNWCertTypeIOSProduction: return @"iOS";
        case kNWCertTypeMacDevelopment:
        case kNWCertTypeMacProduction: return @"macOS";
        case kNWCertTypeSimplified: return @"All";
        case kNWCertTypeWebProduction: return @"Website";
        case kNWCertTypeVoIPServices: return @"VoIP";
        case kNWCertTypeWatchKitServices: return @"WatchKit";
        case kNWCertTypePasses: return @"Pass";
        case kNWCertTypeUnknown: return @"unknown";
    }
    return nil;
}

@implementation NWErrorUtil

+ (NSString *)stringWithCode:(NWError)code
{
    switch (code) {
        case kNWErrorNone                              : return @"No error, that's odd";
            
        case kNWErrorAPNProcessing                     : return @"APN processing error";
        case kNWErrorAPNMissingDeviceToken             : return @"APN missing device token";
        case kNWErrorAPNMissingTopic                   : return @"APN missing topic";
        case kNWErrorAPNMissingPayload                 : return @"APN missing payload";
        case kNWErrorAPNInvalidTokenSize               : return @"APN invalid token size";
        case kNWErrorAPNInvalidTopicSize               : return @"APN invalid topic size";
        case kNWErrorAPNInvalidPayloadSize             : return @"APN invalid payload size";
        case kNWErrorAPNInvalidTokenContent            : return @"APN invalid token";
        case kNWErrorAPNUnknownReason                  : return @"APN unknown reason";
        case kNWErrorAPNShutdown                       : return @"APN shutdown";
        case kNWErrorAPNUnknownErrorCode               : return @"APN unknown error code";
            
        case kNWErrorPushResponseCommand               : return @"Push response command unknown";
        case kNWErrorPushNotConnected                  : return @"Push reconnect requires connection";
        case kNWErrorPushWriteFail                     : return @"Push not fully sent";
            
        case kNWErrorFeedbackLength                    : return @"Feedback data length unexpected";
        case kNWErrorFeedbackTokenLength               : return @"Feedback token length unexpected";
            
        case kNWErrorSocketCreate                      : return @"Socket cannot be created";
        case kNWErrorSocketResolveHostName             : return @"Socket host cannot be resolved";
        case kNWErrorSocketConnect                     : return @"Socket connecting failed";
        case kNWErrorSocketFileControl                 : return @"Socket file control failed";
        case kNWErrorSocketOptions                     : return @"Socket options cannot be set";
            
        case kNWErrorSSLConnection                     : return @"SSL connection cannot be set";
        case kNWErrorSSLContext                        : return @"SSL context cannot be created";
        case kNWErrorSSLIOFuncs                        : return @"SSL callbacks cannot be set";
        case kNWErrorSSLPeerDomainName                 : return @"SSL peer domain name cannot be set";
        case kNWErrorSSLCertificate                    : return @"SSL certificate cannot be set";
        case kNWErrorSSLDroppedByServer                : return @"SSL handshake dropped by server";
        case kNWErrorSSLAuthFailed                     : return @"SSL handshake authentication failed";
        case kNWErrorSSLHandshakeFail                  : return @"SSL handshake failed";
        case kNWErrorSSLHandshakeUnknownRootCert       : return @"SSL handshake root not a known anchor";
        case kNWErrorSSLHandshakeNoRootCert            : return @"SSL handshake chain not verifiable to root";
        case kNWErrorSSLHandshakeCertExpired           : return @"SSL handshake expired certificates";
        case kNWErrorSSLHandshakeXCertChainInvalid     : return @"SSL handshake invalid certificate chain";
        case kNWErrorSSLHandshakeClientCertRequested   : return @"SSL handshake expecting client cert";
        case kNWErrorSSLHandshakeServerAuthCompleted   : return @"SSL handshake auth interrupted";
        case kNWErrorSSLHandshakePeerCertExpired       : return @"SSL handshake certificate expired";
        case kNWErrorSSLHandshakePeerCertRevoked       : return @"SSL handshake certificate revoked";
        case kNWErrorSSLHandshakePeerCertUnknown       : return @"SSL handshake certificate unknown";
        case kNWErrorSSLHandshakeInternalError         : return @"SSL handshake internal error";
        case kNWErrorSSLInDarkWake                     : return @"SSL handshake in dark wake";
        case kNWErrorSSLHandshakeClosedAbort           : return @"SSL handshake connection closed via error";
        case kNWErrorSSLHandshakeTimeout               : return @"SSL handshake timeout";
            
        case kNWErrorReadDroppedByServer               : return @"Read connection dropped by server";
        case kNWErrorReadClosedAbort                   : return @"Read connection error";
        case kNWErrorReadClosedGraceful                : return @"Read connection closed";
        case kNWErrorReadFail                          : return @"Read failed";
            
        case kNWErrorWriteDroppedByServer              : return @"Write connection dropped by server";
        case kNWErrorWriteClosedAbort                  : return @"Write connection error";
        case kNWErrorWriteClosedGraceful               : return @"Write connection closed";
        case kNWErrorWriteFail                         : return @"Write failed";
            
        case kNWErrorIdentityCopyCertificate           : return @"Identity does not contain certificate";
        case kNWErrorIdentityCopyPrivateKey            : return @"Identity does not contain private key";
            
        case kNWErrorPKCS12Import                      : return @"PKCS12 data cannot be imported";
        case kNWErrorPKCS12EmptyData                   : return @"PKCS12 data is empty";
        case kNWErrorPKCS12Decode                      : return @"PKCS12 data cannot be read or is malformed";
        case kNWErrorPKCS12AuthFailed                  : return @"PKCS12 data password incorrect";
        case kNWErrorPKCS12Password                    : return @"PKCS12 data wrong password";
        case kNWErrorPKCS12PasswordRequired            : return @"PKCS12 data password required";
        case kNWErrorPKCS12NoItems                     : return @"PKCS12 data contains no identities";
        case kNWErrorPKCS12MultipleItems               : return @"PKCS12 data contains multiple identities";
            
        case kNWErrorKeychainCopyMatching              : return @"Keychain cannot be searched";
        case kNWErrorKeychainItemNotFound              : return @"Keychain does not contain private key";
        case kNWErrorKeychainCreateIdentity            : return @"Keychain does not contain certificate";
    }
    return @"Unknown";
}

#pragma mark - Helpers

+ (NSError *)errorWithErrorCode:(NWError)code reason:(NSInteger)reason
{
    NSString *description = [self stringWithCode:code];
    if (reason) description = [NSString stringWithFormat:@"%@ (%i)", description, (int)reason];
    NSMutableDictionary *info = @{ NSLocalizedDescriptionKey:description }.mutableCopy;
    if (reason) [info setValue:@(reason) forKey:NWErrorReasonCodeKey];
    return [NSError errorWithDomain:@"NWPusherErrorDomain" code:code userInfo:info];
}

+ (BOOL)noWithErrorCode:(NWError)code error:(NSError *__autoreleasing *)error
{
    return [self noWithErrorCode:code reason:0 error:error];
}

+ (BOOL)noWithErrorCode:(NWError)code reason:(NSInteger)reason error:(NSError *__autoreleasing *)error
{
    NSAssert(code != kNWErrorNone, @"code != kNWErrorNone");
    if (error) *error = [self errorWithErrorCode:code reason:reason];
    return NO;
}

+ (id)nilWithErrorCode:(NWError)code error:(NSError *__autoreleasing *)error
{
    return [self nilWithErrorCode:code reason:0 error:error];
}

+ (id)nilWithErrorCode:(NWError)code reason:(NSInteger)reason error:(NSError *__autoreleasing *)error
{
    NSAssert(code != kNWErrorNone, @"code != kNWErrorNone");
    if (error) *error = [self errorWithErrorCode:code reason:reason];
    return nil;
}

@end
