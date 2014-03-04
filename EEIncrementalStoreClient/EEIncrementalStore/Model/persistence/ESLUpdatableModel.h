//
//  ESLUpdatableModel.h
//  RubricaSede
//
//  Created by Luca Masini on 26/03/13.
//  Copyright (c) 2013 Luca Masini. All rights reserved.
//

@protocol ESLUpdatableModel <NSObject>

@required

@property (readonly) id businessIdentifier;

+ (NSString*)businessIdentifierAttributeName;
+ (NSArray*)deserializeData:(NSData*)data;
- (void)fillWithDataDictionary:(NSObject*)dictionary;
- (BOOL)needToBeUpdatedWith:(NSObject*)dictionary;

@end
