//
//  NSManagedObject+DataMapper.m
//  RubricaSede
//
//  Created by Luca Masini on 03/04/13.
//  Copyright (c) 2013 Luca Masini. All rights reserved.
//

#import "NSManagedObject+DataMapper.h"

@implementation NSManagedObject (DataMapper)

- (id)businessIdentifier {
    
    @throw [NSException exceptionWithName:NSUndefinedKeyException reason:@"Unimplemented method in abstract category DataMapper" userInfo:nil];
}

+ (NSString*)businessIdentifierAttributeName {
    
    @throw [NSException exceptionWithName:NSUndefinedKeyException reason:@"Unimplemented method in abstract category DataMapper" userInfo:nil];
}

+ (NSArray*)deserializeData:(NSData*)data {
    
    return [NSJSONSerialization JSONObjectWithData:data  options:kNilOptions error:nil];
    
}

- (void)fillWithDataDictionary:(NSObject *)dictionary {
    
    [self fillManagedObject:self withDictionary:dictionary andParentObject:nil];
}

- (BOOL)needToBeUpdatedWith:(NSObject*)dictionary {
    
    return YES;
    
}

- (void)fillManagedObject:(NSManagedObject*)mo withDictionary:(NSObject*)dictionary andParentObject:(NSManagedObject*)parentMO{
    
    NSManagedObjectContext *context = [mo managedObjectContext];
    NSEntityDescription *entity = [mo entity];
    NSArray *attKeys = [[entity attributesByName] allKeys];
    NSDictionary *atttributesDict = [dictionary dictionaryWithValuesForKeys:attKeys];
    [mo setValuesForKeysWithDictionary:atttributesDict];
    
    NSManagedObject* (^createChild)(NSDictionary *childDict, NSEntityDescription *destEntity, NSManagedObjectContext *context);
    
    createChild = ^(NSDictionary *childDict, NSEntityDescription *destEntity, NSManagedObjectContext *context) {
        
        NSManagedObject *destMO = [[NSManagedObject alloc] initWithEntity:destEntity insertIntoManagedObjectContext:context];
        
        [self fillManagedObject:destMO withDictionary:childDict andParentObject:mo];
        
        return destMO;
        
    };
    
    NSDictionary *relationshipsByName = [entity relationshipsByName];
    NSManagedObject *destMO = nil;
    
    for (NSString *key in relationshipsByName) {
        
        id childStructure = [dictionary valueForKey:key];
        if (!childStructure) continue;
        
        NSRelationshipDescription *relDesc = [relationshipsByName valueForKey:key];
        NSEntityDescription *destEntity = [relDesc destinationEntity];

        if ([relDesc isToMany] == NO) {
            
            if ([parentMO.entity.name isEqualToString:destEntity.name]) {
                
                destMO = parentMO;
            }
            else{
                
                destMO = createChild(childStructure, destEntity, context);
            }
            
            [mo setValue:destMO forKey:key];
            
            continue;
            
        }

        id childSet;

        if( relDesc.isOrdered ) {
            
            childSet = [[NSMutableOrderedSet alloc] init];
            
        }else{
            
            childSet = [[NSMutableSet alloc] init];
        }
        
        for (NSDictionary *childDict in childStructure) {

            if ([parentMO.entity.name isEqualToString:destEntity.name]) {
                
                destMO = parentMO;
            }
            else{
                
                destMO = createChild(childDict, destEntity, context);
            }
            
            [childSet addObject:destMO];
        }
        
        [mo setValue:childSet forKey:key];
    }
}

@end
