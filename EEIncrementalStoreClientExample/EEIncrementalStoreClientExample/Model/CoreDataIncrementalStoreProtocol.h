//
//  CoreDataIncrementalStoreProtocol.h
//  AFISProva
//
//  Created by roberto avanzi on 19/07/13.
//  Copyright (c) 2013 Esselunga. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CoreDataIncrementalStoreProtocol<NSObject>

@property (readonly, strong, atomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, atomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, atomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic,strong)  id incrementalStore;
- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@end
