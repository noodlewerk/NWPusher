//
//  NWType.h
//  Pusher
//
//  Copyright (c) 2014 noodlewerk. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum { // NWNotificationType
    kNWNotificationType0 = 0,
    kNWNotificationType1 = 1,
    kNWNotificationType2 = 2,
} NWNotificationType;

typedef id NWIdentityRef; // SecIdentityRef
typedef id NWCertificateRef; // SecCertificateRef
typedef id NWKeyRef; // SecKeyRef

typedef enum { // NWError
    kNWSuccess                                 =    0,
    
    kNWErrorAPNProcessing                      =   -1,
    kNWErrorAPNMissingDeviceToken              =   -2,
    kNWErrorAPNMissingTopic                    =   -3,
    kNWErrorAPNMissingPayload                  =   -4,
    kNWErrorAPNInvalidTokenSize                =   -5,
    kNWErrorAPNInvalidTopicSize                =   -6,
    kNWErrorAPNInvalidPayloadSize              =   -7,
    kNWErrorAPNInvalidTokenContent             =   -8,
    kNWErrorAPNUnknownReason                   =   -9,
    kNWErrorAPNShutdown                        =  -10,
    
    kNWErrorPushResponseCommand                = -107,
    kNWErrorPushNotConnected                   = -111,
    kNWErrorPushWriteFail                      = -112,
    
    kNWErrorFeedbackLength                     = -108,
    kNWErrorFeedbackTokenLength                = -109,
    
    kNWErrorSocketCreate                       = -222,
    kNWErrorSocketConnect                      = -201,
    kNWErrorSocketResolveHostName              = -219,
    kNWErrorSocketFileControl                  = -220,
    kNWErrorSocketOptions                      = -221,
    
    kNWErrorSSLConnection                      = -204,
    kNWErrorSSLContext                         = -202,
    kNWErrorSSLIOFuncs                         = -203,
    kNWErrorSSLPeerDomainName                  = -205,
    kNWErrorSSLCertificate                     = -206,
    kNWErrorSSLDroppedByServer                 = -207,
    kNWErrorSSLAuthFailed                      = -208,
    kNWErrorSSLHandshakeFail                   = -209,
    kNWErrorSSLHandshakeTimeout                = -218,
    
    kNWErrorReadDroppedByServer                = -210,
    kNWErrorReadClosedAbort                    = -211,
    kNWErrorReadClosedGraceful                 = -212,
    kNWErrorReadFail                           = -213,
    
    kNWErrorWriteDroppedByServer               = -214,
    kNWErrorWriteClosedAbort                   = -215,
    kNWErrorWriteClosedGraceful                = -216,
    kNWErrorWriteFail                          = -217,
    
    kNWErrorIdentityCopyCertificate            = -304,
    kNWErrorIdentityCopyPrivateKey             = -310,
    
    kNWErrorPKCS12Import                       = -306,
    kNWErrorPKCS12EmptyData                    = -305,
    kNWErrorPKCS12Decode                       = -311,
    kNWErrorPKCS12AuthFailed                   = -312,
    kNWErrorPKCS12Password                     = -313,
    kNWErrorPKCS12NoItems                      = -307,
    kNWErrorPKCS12MutlipleItems                = -309,
    
    kNWErrorKeychainCopyMatching               = -401,
    kNWErrorKeychainItemNotFound               = -302,
    kNWErrorKeychainCreateIdentity             = -303,
} NWError;


@interface NWErrorUtil : NSObject

+ (NSString *)stringWithError:(NWError)error;

@end

