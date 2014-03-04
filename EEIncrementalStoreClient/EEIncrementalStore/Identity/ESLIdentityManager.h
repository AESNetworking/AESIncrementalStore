//
//  ESLIdentityManager
//  RubricaSede
//
//  Created by Luca Masini on 27/02/13.
//  Copyright (c) 2013 Luca Masini. All rights reserved.
//


extern NSString * const IdentityManagerCertificateReceived;

@interface ESLIdentityManager : NSObject

+ (ESLIdentityManager *) sharedInstance;

#pragma mark - class interface methods, returned type should be released using CFRelease!!
-(SecIdentityRef)createIdentityFromPersistentRef:(CFDataRef)persistent_ref;
-(SecCertificateRef)createCertificateFromIdentity:(SecIdentityRef)identity_ref;
// Roberto: add method for direct access to Identity Ref
-(SecIdentityRef)retrieveSecIdentityRefFromIdentifier:(NSString *)identifier;

@end
