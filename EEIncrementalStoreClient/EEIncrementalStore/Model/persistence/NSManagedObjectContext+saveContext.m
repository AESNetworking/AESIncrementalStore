//
//  NSManagedObjectContext+saveContext.m
//  CheckList
//
//  Created by roberto avanzi on 03/04/14.
//  Copyright (c) 2014 Esselunga. All rights reserved.
//

#import "NSManagedObjectContext+saveContext.h"

@implementation NSManagedObjectContext (saveContext)

- (void)saveWithCheck {
    NSError *error;
    
    if ([self hasChanges]) {
        if (![self save:&error]) {
                DEBUG_LOG(@"Unresolved error %@, %@", error, [error userInfo]);
        }
    }
}

- (void)saveContext {
    [self performBlock:^{
        [self saveWithCheck];
        if (self.parentContext!=nil) {
            [self.parentContext performBlock:^{
                [self.parentContext saveWithCheck];
            }];
        }
    }];
}

- (void)saveContextAndWait {
    [self performBlockAndWait:^{
        [self saveWithCheck];
        if (self.parentContext!=nil) {
            [self.parentContext performBlockAndWait:^{
                [self.parentContext saveWithCheck];
            }];
        }
    }];
}

@end
