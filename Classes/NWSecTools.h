//
//  NWSecTools.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>


@interface NWSecTools : NSObject

+ (NWIdentityRef)identityWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password error:(NSError **)error;
+ (NSArray *)identitiesWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password error:(NSError **)error;
+ (NSArray *)keychainCertificatesWithError:(NSError **)error;
+ (NWCertificateRef)certificateWithIdentity:(NWIdentityRef)identity error:(NSError **)error;
+ (NWKeyRef)keyWithIdentity:(NWIdentityRef)identity error:(NSError **)error;

+ (NWCertificateRef)certificateWithData:(NSData *)data;
+ (NSString *)summaryWithCertificate:(NWCertificateRef)certificate;
+ (BOOL)isSandboxIdentity:(NWIdentityRef)identity;
+ (BOOL)isSandboxCertificate:(NWCertificateRef)certificate;
+ (BOOL)isPushCertificate:(NWCertificateRef)certificate;

+ (NSDictionary *)inspectIdentity:(NWIdentityRef)identity;

#if !TARGET_OS_IPHONE
+ (NWIdentityRef)keychainIdentityWithCertificate:(NWCertificateRef)certificate error:(NSError **)error;
#endif

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
