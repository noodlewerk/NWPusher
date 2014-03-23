//
//  NWSecTools.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>


@interface NWSecTools : NSObject

+ (NWError)identityWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password identity:(NWIdentityRef *)identity;
+ (NWError)identitiesWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password identities:(NSArray **)identities;
+ (NWError)keychainCertificates:(NSArray **)certificates;
+ (NWError)certificateWithIdentity:(NWIdentityRef)identity certificate:(NWCertificateRef *)certificate;
+ (NWError)keyWithIdentity:(NWIdentityRef)identity key:(NWKeyRef *)key;

+ (NWCertificateRef)certificateWithData:(NSData *)data;
+ (NSString *)summaryWithCertificate:(NWCertificateRef)certificate;
+ (BOOL)isSandboxIdentity:(NWIdentityRef)identity;
+ (BOOL)isSandboxCertificate:(NWCertificateRef)certificate;
+ (BOOL)isPushCertificate:(NWCertificateRef)certificate;

+ (NSDictionary *)inspectIdentity:(NWIdentityRef)identity;

#if !TARGET_OS_IPHONE
+ (NWError)keychainIdentityWithCertificate:(NWCertificateRef)certificate identity:(NWIdentityRef *)identity;
#endif

// deprecated
#if !TARGET_OS_IPHONE
+ (NWError)identityWithCertificateRef:(SecCertificateRef)certificate identity:(SecIdentityRef *)identity __attribute__((deprecated));
+ (NWError)identityWithCertificateData:(NSData *)certificate identity:(SecIdentityRef *)identity __attribute__((deprecated));
#endif
+ (NSArray *)keychainCertificates __attribute__((deprecated));
+ (NSString *)identifierForCertificate:(SecCertificateRef)certificate __attribute__((deprecated));
+ (SecCertificateRef)certificateForIdentity:(SecIdentityRef)identity __attribute__((deprecated));
+ (BOOL)isSandboxCertificateRef:(SecCertificateRef)certificate __attribute__((deprecated));

@end
