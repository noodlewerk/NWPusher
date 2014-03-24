//
//  NWPusher.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>

@class NWNotification, NWSSLConnection;

typedef NWError NWPusherResult; // deprecated


@interface NWPusher : NSObject

@property (nonatomic, readonly) NWSSLConnection *connection;

- (NWError)connectWithIdentity:(NWIdentityRef)identity;
- (NWError)connectWithPKCS12Data:(NSData *)data password:(NSString *)password;
- (NWError)reconnect;
- (void)disconnect;

- (NWError)pushPayload:(NSString *)payload token:(NSString *)token identifier:(NSUInteger)identifier;
- (NWError)pushNotification:(NWNotification *)notification type:(NWNotificationType)type;
- (NWError)fetchFailedIdentifier:(NSUInteger *)identifier apnError:(NWError *)apnError;

// deprecated
#if !TARGET_OS_IPHONE
- (NWError)connectWithCertificateRef:(SecCertificateRef)certificate __attribute__((deprecated));
#endif
- (NWError)connectWithIdentityRef:(SecIdentityRef)identity __attribute__((deprecated));
+ (NSString *)stringFromResult:(NWError)result __attribute__((deprecated));
- (NWError)fetchFailedIdentifier:(NSUInteger *)identifier __attribute__((deprecated));

@end

// deprecated
enum {
    kNWPusherResultSuccess                             = kNWSuccess,
    
    kNWPusherResultAPNProcessingError                  = kNWErrorAPNProcessing,
    kNWPusherResultAPNMissingDeviceToken               = kNWErrorAPNMissingDeviceToken,
    kNWPusherResultAPNMissingTopic                     = kNWErrorAPNMissingTopic,
    kNWPusherResultAPNMissingPayload                   = kNWErrorAPNMissingPayload,
    kNWPusherResultAPNInvalidTokenSize                 = kNWErrorAPNInvalidTokenSize,
    kNWPusherResultAPNInvalidTopicSize                 = kNWErrorAPNInvalidTopicSize,
    kNWPusherResultAPNInvalidPayloadSize               = kNWErrorAPNInvalidPayloadSize,
    kNWPusherResultAPNInvalidToken                     = kNWErrorAPNInvalidTokenContent,
    kNWPusherResultAPNUnknownReason                    = kNWErrorAPNUnknownReason,
    kNWPusherResultAPNShutdown                         = kNWErrorAPNShutdown,
    
    kNWPusherResultEmptyPayload,
    kNWPusherResultInvalidPayload,
    kNWPusherResultEmptyToken,
    kNWPusherResultInvalidToken,
    kNWPusherResultPayloadTooLong,
    kNWPusherResultUnexpectedResponseCommand           = kNWErrorPushResponseCommand,
    kNWPusherResultUnexpectedResponseLength            = kNWErrorFeedbackLength,
    kNWPusherResultUnexpectedTokenLength               = kNWErrorFeedbackTokenLength,
    kNWPusherResultIDOutOfSync,
    kNWPusherResultNotConnected                        = kNWErrorPushNotConnected,
    
    kNWPusherResultIOConnectFailed                     = kNWErrorSocketConnect,
    kNWPusherResultIOConnectSocketCallbacks            = kNWErrorSSLIOFuncs,
    
    kNWPusherResultIOConnectSSL                        = kNWErrorSSLConnection,
    kNWPusherResultIOConnectSSLContext                 = kNWErrorSSLContext,
    kNWPusherResultIOConnectPeerDomain                 = kNWErrorSSLPeerDomainName,
    kNWPusherResultIOConnectAssignCertificate          = kNWErrorSSLCertificate,
    kNWPusherResultIOConnectSSLHandshakeConnection     = kNWErrorSSLDroppedByServer,
    kNWPusherResultIOConnectSSLHandshakeAuthentication = kNWErrorSSLAuthFailed,
    kNWPusherResultIOConnectSSLHandshakeError          = kNWErrorSSLHandshakeFail,
    kNWPusherResultIOConnectTimeout                    = kNWErrorSSLHandshakeTimeout,
    
    kNWPusherResultIOReadDroppedByServer               = kNWErrorReadDroppedByServer,
    kNWPusherResultIOReadConnectionError               = kNWErrorReadClosedAbort,
    kNWPusherResultIOReadConnectionClosed              = kNWErrorReadClosedGraceful,
    kNWPusherResultIOReadError                         = kNWErrorReadFail,
    kNWPusherResultIOWriteDroppedByServer              = kNWErrorWriteDroppedByServer,
    kNWPusherResultIOWriteConnectionError              = kNWErrorWriteClosedAbort,
    kNWPusherResultIOWriteConnectionClosed             = kNWErrorWriteClosedGraceful,
    kNWPusherResultIOWriteError                        = kNWErrorWriteFail,
    
    kNWPusherResultCertificateInvalid,
    kNWPusherResultCertificatePrivateKeyMissing        = kNWErrorKeychainItemNotFound,
    kNWPusherResultCertificateCreateIdentity           = kNWErrorKeychainCreateIdentity,
    kNWPusherResultCertificateNotFound                 = kNWErrorIdentityCopyCertificate,
    
    kNWPusherResultPKCS12EmptyData                     = kNWErrorPKCS12EmptyData,
    kNWPusherResultPKCS12InvalidData                   = kNWErrorPKCS12Import,
    kNWPusherResultPKCS12NoItems                       = kNWErrorPKCS12NoItems,
    kNWPusherResultPKCS12MutlipleItems                 = kNWErrorPKCS12MutlipleItems,
    kNWPusherResultPKCS12NoIdentity,
    
    kNWPusherResultKeychainFail                        = kNWErrorKeychainCopyMatching,
};
