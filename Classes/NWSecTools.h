//
//  NWSecTools.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>

/** A collection of tools for reading, converting and inspecting Keychain objects and PKCS #12 files.

 This is practically the glue that connects this framework to the Security framework and allows interacting with the OS Keychain and PKCS #12 files.

 `NWIdentityRef`, `NWCertificateRef` and `NWKeyRef` represent respectively `SecIdentityRef`, `SecCertificateRef`, `SecKeyRef`. Methods return `nil` or `NO` if an error occurred.
 */
@interface NWSecTools : NSObject

/** @name Initialization */

/** Read an identity from a PKCS #12 file (.p12) that contains a single certificate-key pair. */
+ (NWIdentityRef)identityWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password error:(NSError **)error;

/** Read all identities from a PKCS #12 file (.p12). */
+ (NSArray *)identitiesWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password error:(NSError **)error;

/** List all push certificates present in the OS Keychain. */
+ (NSArray *)keychainCertificatesWithError:(NSError **)error;

/** @name Sec Wrappers */

/** Returns the certificate contained by the identity. */
+ (NWCertificateRef)certificateWithIdentity:(NWIdentityRef)identity error:(NSError **)error;

/** Returns the key contained by the identity. */
+ (NWKeyRef)keyWithIdentity:(NWIdentityRef)identity error:(NSError **)error;

/** Reads an X.509 certificate from a DER file. */
+ (NWCertificateRef)certificateWithData:(NSData *)data;

#if !TARGET_OS_IPHONE
/** Searches the OS Keychain for an identity (the key) that matches the certifiate. (OS X only) */
+ (NWIdentityRef)keychainIdentityWithCertificate:(NWCertificateRef)certificate error:(NSError **)error;
#endif

/** @name Inspection */

/** Extracts the summary string. */
+ (NSString *)summaryWithCertificate:(NWCertificateRef)certificate;

/** Tells if the identity is for pushing to the Development (sandbox) server. */
+ (BOOL)isSandboxIdentity:(NWIdentityRef)identity;

/** Tells if the certificate is for pushing to the Development (sandbox) server. */
+ (BOOL)isSandboxCertificate:(NWCertificateRef)certificate;

/** Tells if the certificate can be used for connecting with APNS. */
+ (BOOL)isPushCertificate:(NWCertificateRef)certificate;

/** Composes a dictionary describing the characteristics of the identity. */
+ (NSDictionary *)inspectIdentity:(NWIdentityRef)identity;

// deprecated

+ (NWError)identityWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password identity:(NWIdentityRef *)identity __deprecated;
+ (NWError)identitiesWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password identities:(NSArray **)identities __deprecated;
+ (NWError)keychainCertificates:(NSArray **)certificates __deprecated;
+ (NWError)certificateWithIdentity:(NWIdentityRef)identity certificate:(NWCertificateRef *)certificate __deprecated;
+ (NWError)keyWithIdentity:(NWIdentityRef)identity key:(NWKeyRef *)key __deprecated;

#if !TARGET_OS_IPHONE
+ (NWError)keychainIdentityWithCertificate:(NWCertificateRef)certificate identity:(NWIdentityRef *)identity __deprecated;
#endif

@end
