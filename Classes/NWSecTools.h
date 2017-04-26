//
//  NWSecTools.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>

/** A collection of tools for reading, converting and inspecting Keychain objects and PKCS #12 files.

 This is practically the glue that connects this framework to the Security framework and allows interacting with the OS Keychain and PKCS #12 files. It is mostly an Objective-C around the Security framework, including the benefits of ARC. `NWIdentityRef`, `NWCertificateRef` and `NWKeyRef` represent respectively `SecIdentityRef`, `SecCertificateRef`, `SecKeyRef`. It uses Cocoa-style error handling, so methods return `nil` or `NO` if an error occurred.
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
/** Searches the OS Keychain for an identity (the key) that matches the certificate. (OS X only) */
+ (NWIdentityRef)keychainIdentityWithCertificate:(NWCertificateRef)certificate error:(NSError **)error;
#endif

/** @name Inspection */

/** Extracts the type and summary string. */
+ (NWCertType)typeWithCertificate:(NWCertificateRef)certificate summary:(NSString **)summary;

/** Extracts the summary string. */
+ (NSString *)summaryWithCertificate:(NWCertificateRef)certificate;

/** Tells what environment options can be used with this identity (Development(sandbox)/Production server or both). */
+ (NWEnvironmentOptions)environmentOptionsForIdentity:(NWIdentityRef)identity;

/** Tells what environment options can be used with this certificate (Development(sandbox)/Production server or both). */
+ (NWEnvironmentOptions)environmentOptionsForCertificate:(NWCertificateRef)certificate;

/** Tells if the certificate can be used for connecting with APNs. */
+ (BOOL)isPushCertificate:(NWCertificateRef)certificate;

/** Composes a dictionary describing the characteristics of the identity. */
+ (NSDictionary *)inspectIdentity:(NWIdentityRef)identity;

#if !TARGET_OS_IPHONE
/** Extracts the expiration date. */
+ (NSDate *)expirationWithCertificate:(NWCertificateRef)certificate;

/** Extracts given properties of certificate, see `SecCertificateOIDs.h`, use `nil` to get all. */
+ (NSDictionary *)valuesWithCertificate:(NWCertificateRef)certificate keys:(NSArray *)keys error:(NSError **)error;
#endif

// deprecated

+ (BOOL)isSandboxIdentity:(NWIdentityRef)identity __deprecated;
+ (BOOL)isSandboxCertificate:(NWCertificateRef)certificate __deprecated;
+ (NWEnvironment)environmentForIdentity:(NWIdentityRef)identity;
+ (NWEnvironment)environmentForCertificate:(NWCertificateRef)certificate;

@end
