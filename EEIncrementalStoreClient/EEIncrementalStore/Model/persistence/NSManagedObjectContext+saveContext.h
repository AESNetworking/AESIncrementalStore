//
//  NSManagedObjectContext+saveContext.h
//  CheckList
//
//  Created by roberto avanzi on 03/04/14.
//  Copyright (c) 2014 Esselunga. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSManagedObjectContext (saveContext)

- (void)saveContext;
- (void)saveContextAndWait;

@end
