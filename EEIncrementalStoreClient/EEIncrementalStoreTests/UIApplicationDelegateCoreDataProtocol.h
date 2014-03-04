//
//  UIApplicationDelegateCoreDataProtocol.h
//  AFISProva
//
//  Created by roberto avanzi on 19/07/13.
//  Copyright (c) 2013 Esselunga. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol UIApplicationDelegateCoreDataProtocol <NSObject>

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic,strong)  id incrementalStore;
- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@end
