//
//  NWSecTools.h
//  Pusher
//
//  Created by Leo on 9/9/12.
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

@interface NWSecTools : NSObject

+ (BOOL)identityWithCertificateRef:(SecCertificateRef)certificate identity:(SecIdentityRef *)identity;
+ (BOOL)identityWithCertificateData:(NSData *)certificate identity:(SecIdentityRef *)identity;
+ (BOOL)identityWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password identity:(SecIdentityRef *)identity;

+ (BOOL)keychainCertificates:(NSArray **)certificates;
+ (BOOL)isDevelopmentCertificate:(SecCertificateRef)certificate;
+ (NSString *)identifierForCertificate:(SecCertificateRef)certificate;

@end
