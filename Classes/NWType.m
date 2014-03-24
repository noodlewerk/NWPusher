//
//  NWType.m
//  Pusher
//
//  Copyright (c) 2014 noodlewerk. All rights reserved.
//

#import "NWType.h"

@implementation NWErrorUtil

+ (NSString *)stringWithError:(NWError)error
{
    switch (error) {
        case kNWSuccess                                : return @"Success (no error)";
            
        case kNWErrorAPNProcessing                     : return @"APN processing error";
        case kNWErrorAPNMissingDeviceToken             : return @"APN missing device token";
        case kNWErrorAPNMissingTopic                   : return @"APN missing topic";
        case kNWErrorAPNMissingPayload                 : return @"APN missing payload";
        case kNWErrorAPNInvalidTokenSize               : return @"APN invalid token size";
        case kNWErrorAPNInvalidTopicSize               : return @"APN invalid topic size";
        case kNWErrorAPNInvalidPayloadSize             : return @"APN invalid payload size";
        case kNWErrorAPNInvalidTokenContent            : return @"APN invalid token";
        case kNWErrorAPNUnknownReason                  : return @"APN unkown reason";
        case kNWErrorAPNShutdown                       : return @"APN shutdown";
            
        case kNWErrorPushResponseCommand               : return @"Push response command unknown";
        case kNWErrorPushNotConnected                  : return @"Push reconnect requires connection";
        case kNWErrorPushWriteFail                     : return @"Push not fully sent";
            
        case kNWErrorFeedbackLength                    : return @"Feedback data length unexpected";
        case kNWErrorFeedbackTokenLength               : return @"Feedback token length unexpected";
            
        case kNWErrorSocketCreate                      : return @"Socket cannot be created";
        case kNWErrorSocketResolveHostName             : return @"Socket host cannot be resolved";
        case kNWErrorSocketConnect                     : return @"Socket connecting failed";
        case kNWErrorSocketFileControl                 : return @"Socket file contol failed";
        case kNWErrorSocketOptions                     : return @"Socket options cannot be set";
            
        case kNWErrorSSLConnection                     : return @"SSL connection cannot be set";
        case kNWErrorSSLContext                        : return @"SSL context cannot be created";
        case kNWErrorSSLIOFuncs                        : return @"SSL callbacks cannot be set";
        case kNWErrorSSLPeerDomainName                 : return @"SSL peer domain name cannot be set";
        case kNWErrorSSLCertificate                    : return @"SSL certificate cannot be set";
        case kNWErrorSSLDroppedByServer                : return @"SSL handshake dropped by server";
        case kNWErrorSSLAuthFailed                     : return @"SSL handshake authentication failed";
        case kNWErrorSSLHandshakeFail                  : return @"SSL handshake failed";
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
        case kNWErrorPKCS12NoItems                     : return @"PKCS12 data contains no identities";
        case kNWErrorPKCS12MutlipleItems               : return @"PKCS12 data contains multiple identities";
            
        case kNWErrorKeychainCopyMatching              : return @"Keychain cannot be searched";
        case kNWErrorKeychainItemNotFound              : return @"Keychain does not contain private key";
        case kNWErrorKeychainCreateIdentity            : return @"Keychain does not contain certificate";
    }
    return @"Unkown";
}

@end
