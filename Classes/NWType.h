//
//  NWType.h
//  Pusher
//
//  Copyright (c) 2014 noodlewerk. All rights reserved.
//

#import <Foundation/Foundation.h>

/** The current and past data formats supported by APNs. For more information see Apple documentation under 'Legacy Information'. */
typedef NS_ENUM(NSInteger, NWNotificationType) {
    /** The 'Simple Notification Format'. The oldest format, simply concatenates the device token and payload. */
    kNWNotificationType0 = 0,
    /** The 'Enhanced Notification Format'. Similar to the previous format, but includes and identifier and expiration date. */
    kNWNotificationType1 = 1,
    /** The 'Binary Interface and Notification Format'. The latest, more extensible format that allows for attributes like priority. */
    kNWNotificationType2 = 2,
};

/** An ARC-friendly replacement of SecIdentityRef. */
typedef id NWIdentityRef;

/** An ARC-friendly replacement of SecCertificateRef. */
typedef id NWCertificateRef;

/** An ARC-friendly replacement of SecKeyRef. */
typedef id NWKeyRef;

/** List all error codes. */
typedef NS_ENUM(NSInteger, NWError) {
    /** No error, that's odd. */
    kNWErrorNone                               =    0,

    /** APN processing error. */
    kNWErrorAPNProcessing                      =   -1,
    /** APN missing device token. */
    kNWErrorAPNMissingDeviceToken              =   -2,
    /** APN missing topic. */
    kNWErrorAPNMissingTopic                    =   -3,
    /** APN missing payload. */
    kNWErrorAPNMissingPayload                  =   -4,
    /** APN invalid token size. */
    kNWErrorAPNInvalidTokenSize                =   -5,
    /** APN invalid topic size. */
    kNWErrorAPNInvalidTopicSize                =   -6,
    /** APN invalid payload size. */
    kNWErrorAPNInvalidPayloadSize              =   -7,
    /** APN invalid token. */
    kNWErrorAPNInvalidTokenContent             =   -8,
    /** APN unknown reason. */
    kNWErrorAPNUnknownReason                   =   -9,
    /** APN shutdown. */
    kNWErrorAPNShutdown                        =  -10,
    /** APN unknown error code. */
    kNWErrorAPNUnknownErrorCode                =  -11,
    
    /** Push response command unknown. */
    kNWErrorPushResponseCommand                = -107,
    /** Push reconnect requires connection. */
    kNWErrorPushNotConnected                   = -111,
    /** Push not fully sent. */
    kNWErrorPushWriteFail                      = -112,
    
    /** Feedback data length unexpected. */
    kNWErrorFeedbackLength                     = -108,
    /** Feedback token length unexpected. */
    kNWErrorFeedbackTokenLength                = -109,
    
    /** Socket cannot be created. */
    kNWErrorSocketCreate                       = -222,
    /** Socket connecting failed. */
    kNWErrorSocketConnect                      = -201,
    /** Socket host cannot be resolved. */
    kNWErrorSocketResolveHostName              = -219,
    /** Socket file control failed. */
    kNWErrorSocketFileControl                  = -220,
    /** Socket options cannot be set. */
    kNWErrorSocketOptions                      = -221,
    
    /** SSL connection cannot be set. */
    kNWErrorSSLConnection                      = -204,
    /** SSL context cannot be created. */
    kNWErrorSSLContext                         = -202,
    /** SSL callbacks cannot be set. */
    kNWErrorSSLIOFuncs                         = -203,
    /** SSL peer domain name cannot be set. */
    kNWErrorSSLPeerDomainName                  = -205,
    /** SSL certificate cannot be set. */
    kNWErrorSSLCertificate                     = -206,
    /** SSL handshake dropped by server. */
    kNWErrorSSLDroppedByServer                 = -207,
    /** SSL handshake authentication failed. */
    kNWErrorSSLAuthFailed                      = -208,
    /** SSL handshake failed. */
    kNWErrorSSLHandshakeFail                   = -209,
    /** SSL handshake root not a known anchor. */
    kNWErrorSSLHandshakeUnknownRootCert        = -223,
    /** SSL handshake chain not verifiable to root. */
    kNWErrorSSLHandshakeNoRootCert             = -224,
    /** SSL handshake expired certificates. */
    kNWErrorSSLHandshakeCertExpired            = -225,
    /** SSL handshake invalid certificate chain. */
    kNWErrorSSLHandshakeXCertChainInvalid      = -226,
    /** SSL handshake expecting client cert. */
    kNWErrorSSLHandshakeClientCertRequested    = -227,
    /** SSL handshake auth interrupted. */
    kNWErrorSSLHandshakeServerAuthCompleted    = -228,
    /** SSL handshake certificate expired. */
    kNWErrorSSLHandshakePeerCertExpired        = -229,
    /** SSL handshake certificate revoked. */
    kNWErrorSSLHandshakePeerCertRevoked        = -230,
    /** SSL handshake certificate unknown. */
    kNWErrorSSLHandshakePeerCertUnknown        = -233,
    /** SSL handshake internal error. */
    kNWErrorSSLHandshakeInternalError          = -234,
    /** SSL handshake in dark wake. */
    kNWErrorSSLInDarkWake                      = -231,
    /** SSL handshake connection closed via error. */
    kNWErrorSSLHandshakeClosedAbort            = -232,
    /** SSL handshake timeout. */
    kNWErrorSSLHandshakeTimeout                = -218,
    
    /** Read connection dropped by server. */
    kNWErrorReadDroppedByServer                = -210,
    /** Read connection error. */
    kNWErrorReadClosedAbort                    = -211,
    /** Read connection closed. */
    kNWErrorReadClosedGraceful                 = -212,
    /** Read failed. */
    kNWErrorReadFail                           = -213,
    
    /** Write connection dropped by server. */
    kNWErrorWriteDroppedByServer               = -214,
    /** Write connection error. */
    kNWErrorWriteClosedAbort                   = -215,
    /** Write connection closed. */
    kNWErrorWriteClosedGraceful                = -216,
    /** Write failed. */
    kNWErrorWriteFail                          = -217,
    
    /** Identity does not contain certificate. */
    kNWErrorIdentityCopyCertificate            = -304,
    /** Identity does not contain private key. */
    kNWErrorIdentityCopyPrivateKey             = -310,
    
    /** PKCS12 data cannot be imported. */
    kNWErrorPKCS12Import                       = -306,
    /** PKCS12 data is empty. */
    kNWErrorPKCS12EmptyData                    = -305,
    /** PKCS12 data cannot be read or is malformed. */
    kNWErrorPKCS12Decode                       = -311,
    /** PKCS12 data password incorrect. */
    kNWErrorPKCS12AuthFailed                   = -312,
    /** PKCS12 data wrong password. */
    kNWErrorPKCS12Password                     = -313,
    /** PKCS12 data password required. */
    kNWErrorPKCS12PasswordRequired             = -314,
    /** PKCS12 data contains no identities. */
    kNWErrorPKCS12NoItems                      = -307,
    /** PKCS12 data contains multiple identities. */
    kNWErrorPKCS12MultipleItems                = -309,
    
    /** Keychain cannot be searched. */
    kNWErrorKeychainCopyMatching               = -401,
    /** Keychain does not contain private key. */
    kNWErrorKeychainItemNotFound               = -302,
    /** Keychain does not contain certificate. */
    kNWErrorKeychainCreateIdentity             = -303,
};

typedef NS_ENUM(NSInteger, NWEnvironment) {
    NWEnvironmentNone = 0,
    NWEnvironmentSandbox = 1,
    NWEnvironmentProduction = 2,
    NWEnvironmentAuto = 3,
};

typedef NS_ENUM(NSInteger, NWEnvironmentOptions) {
    NWEnvironmentOptionNone = 0,
    NWEnvironmentOptionSandbox = 1 << NWEnvironmentSandbox,
    NWEnvironmentOptionProduction = 1 << NWEnvironmentProduction,
    NWEnvironmentOptionAny = NWEnvironmentOptionSandbox | NWEnvironmentOptionProduction
};

/** NSError dictionary key for integer code that indicates underlying reason. */
extern NSString * const NWErrorReasonCodeKey;

/** A collection of helper methods to support Cocoa-style error handling (`NSError`).
 
 Most methods in this framework return `NO` or `nil` to indicate an error occurred. In that case an error object will be assigned. This class provides a mapping from codes to description string and some methods to instantiate the `NSError` object.
 */

/** Returns string for given environment, for logging purposes */
NSString * descriptionForEnvironentOptions(NWEnvironmentOptions environmentOptions);
NSString * descriptionForEnvironent(NWEnvironment environment);

@interface NWErrorUtil : NSObject

/** @name Helpers */

/** Assigns the error with provided code and associated description, for returning `NO`. */
+ (BOOL)noWithErrorCode:(NWError)code error:(NSError **)error;
+ (BOOL)noWithErrorCode:(NWError)code reason:(NSInteger)reason error:(NSError **)error;

/** Assigns the error with provided code and associated description, for returning `nil`. */
+ (id)nilWithErrorCode:(NWError)code error:(NSError **)error;
+ (id)nilWithErrorCode:(NWError)code reason:(NSInteger)reason error:(NSError **)error;

@end
