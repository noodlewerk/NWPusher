//
//  NWSecTools.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWPusher.h"
#import <Foundation/Foundation.h>


@interface NWSecTools : NSObject

#if !TARGET_OS_IPHONE
+ (NWPusherResult)identityWithCertificateRef:(SecCertificateRef)certificate identity:(SecIdentityRef *)identity;
+ (NWPusherResult)identityWithCertificateData:(NSData *)certificate identity:(SecIdentityRef *)identity;
#endif
+ (NWPusherResult)identityWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password identity:(SecIdentityRef *)identity;

+ (NSArray *)keychainCertificates;
+ (BOOL)isDevelopmentCertificate:(SecCertificateRef)certificate;
+ (NSString *)identifierForCertificate:(SecCertificateRef)certificate;
+ (SecCertificateRef)certificateForIdentity:(SecIdentityRef)identity;

@end
