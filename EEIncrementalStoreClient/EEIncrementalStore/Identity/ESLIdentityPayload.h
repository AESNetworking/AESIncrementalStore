//
//  ESLIdentityPayload
//  RubricaSede
//
//  Created by Luca Masini on 27/02/13.
//  Copyright (c) 2013 Luca Masini. All rights reserved.



@interface ESLIdentityPayload : NSObject

@property (readonly, nonatomic) SecIdentityRef identityCertificate;
@property (readonly, nonatomic, strong)NSString *serverURL;

-(id)initWithIdentity:(NSData*)identity withPassword:(NSString*)password andServiceURL:(NSString*)serviceURL;

+(NSString *)dictionaryKey;

@end
