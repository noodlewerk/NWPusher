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

@end
