//
//  SLPersistenceManager.m
//  RubricaSede
//
//  Created by Luca Masini on 01/03/13.
//  Copyright (c) 2013 Luca Masini. All rights reserved.
//

#import "ESLPersistenceManager.h"
#import "ESLUpdatableModel.h"
#import "EEIncrementalStore.h"
#import <objc/runtime.h>

NSString * kESLExceptionDidNotSaveMainContext=@"ESLExceptionDidNotSaveMainContext";

@interface ESLPersistenceManager()

@property (nonatomic, strong) NSManagedObjectContext *persistentParentMOC;
@property NSOperationQueue *backgroundQueue;

@end

@implementation ESLPersistenceManager

static NSString * const UpdateFinishedNotification = @"InternalWarnMeWhenContextFinished";

@synthesize managedObjectModel=_managedObjectModel;
@synthesize managedObjectContext=_managedObjectContext;
@synthesize persistentStoreCoordinator=_persistentStoreCoordinator;

// ALL code below, is taken from ADC sample CoreDataBooks, code: CoreDataBooksAppDelegate.m
ESLPersistenceManager * sharedInstance = nil;

+(ESLPersistenceManager*)sharedInstance {
    if (sharedInstance == nil)
    {
        sharedInstance = [ESLPersistenceManager new];

        sharedInstance.backgroundQueue = [NSOperationQueue new];
        sharedInstance.backgroundQueue.name = @"ServiceManagerQueue";
        
        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance
                                                 selector:@selector(updateEntitiesWithData:)
                                                 name:NewNSDataNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance
                                                 selector:@selector(updateEntitiesWithArray:)
                                                     name:NewNSArrayNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance
                                                 selector:@selector(errorUpdatingReleaseProgressIndicator:)
                                                     name:NoNewNSArrayNotification
                                                   object:nil];
    
        sharedInstance=[sharedInstance initInternal];
    }
    
    return sharedInstance;
}

-(id)initInternal {

    if (self=[super init]) {
        // used for first creation of incremental store
        [self managedObjectContext];
    }
    
    return self;
}

- (void)warnMeWhenMainContextIsSaved:(id)observer usingThisSelector:(SEL)aSelector {

    [[NSNotificationCenter defaultCenter] addObserver:observer
                                             selector:aSelector
                                                 name:UpdateFinishedNotification
                                               object:self];
}

-(void)errorUpdatingReleaseProgressIndicator:(NSNotification *)notif {
    [[NSNotificationCenter defaultCenter] postNotificationName:UpdateFinishedNotification object:self];
}

-(void)updateEntitiesWithData:(NSNotification *)notif {

    [self.backgroundQueue addOperationWithBlock:^{
        NSData *bufferConnection = notif.object;
        NSDictionary *userInfo = notif.userInfo;
        
        [self updateLocalEntities:[userInfo objectForKey:@"entityName"]
           withNewDataFromNetwork:bufferConnection
              usingFetchedRequest:[userInfo objectForKey:@"fetchedRequest"]];
    }];
}

- (void)updateEntitiesWithArray:(NSNotification *)notif {
    
    [self.backgroundQueue addOperationWithBlock:^{
        NSArray *entities = notif.object;
        NSDictionary *userInfo = notif.userInfo;
        
        [self updateLocalEntities:[userInfo objectForKey:@"entityName"]
                  withNewEntities:entities
              usingFetchedRequest:[userInfo objectForKey:@"fetchedRequest"]];
    }];
}

- (void)updateLocalEntities:(NSString*)entityName withNewDataFromNetwork:(NSData *) bufferConnection usingFetchedRequest:(NSString*) templateName{
    DEBUG_LOG(@"before parse");
    Class<ESLUpdatableModel> entityClass = NSClassFromString(entityName);
    NSArray * newEntities = [entityClass deserializeData: bufferConnection];

//    NSArray * newEntities =[NSJSONSerialization JSONObjectWithData:bufferConnection  options:kNilOptions error:nil];
    DEBUG_LOG(@"after parse, num of entities: %lu", (unsigned long)newEntities.count);
    
    [self updateLocalEntities:entityName withNewEntities:newEntities usingFetchedRequest:templateName];
    
}

- (void)updateLocalEntities:(NSString*)entityName withNewEntities:(NSArray*)newEntities usingFetchedRequest:(NSString*)templateName{
    
    NSBlockOperation *importOperation = [NSBlockOperation blockOperationWithBlock:^{
        
        if ( newEntities ) {
            
            NSFetchRequest *fetchRequest = [self.managedObjectModel fetchRequestFromTemplateWithName:templateName
                                                                               substitutionVariables:nil];
            
            NSManagedObjectContext *localMOC = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
            localMOC.parentContext = self.managedObjectContext;
            
            NSArray *currentLocalEntities = [localMOC executeFetchRequest:fetchRequest error:nil];
            
            NSMutableDictionary *keysWithEntities = [NSMutableDictionary new];
            
            Class<ESLUpdatableModel> entityClass = NSClassFromString(entityName);
            NSString *businessIdentifierString = [entityClass businessIdentifierAttributeName];
            
            for (NSDictionary *entity in newEntities) {
                
                NSNumber *idCorrente = [entity valueForKey:businessIdentifierString];
                [keysWithEntities setObject:entity forKey:idCorrente];
            }
            
            for(id<ESLUpdatableModel> updatableModel in currentLocalEntities) {
                
                id identifier = updatableModel.businessIdentifier;
                
                NSDictionary *newEntityDictionary = [keysWithEntities objectForKey:identifier];
                
                if(newEntityDictionary && [updatableModel needToBeUpdatedWith:newEntityDictionary]) {
                    
                    [updatableModel fillWithDataDictionary:newEntityDictionary];
                    [keysWithEntities removeObjectForKey:identifier];
                    
                } else {
                    
                    [localMOC deleteObject:updatableModel];
                }
            }
            
            for (NSNumber *entityId in keysWithEntities) {
                
                id<ESLUpdatableModel> newEntity = [NSEntityDescription insertNewObjectForEntityForName:entityName
                                                                               inManagedObjectContext:localMOC];
                
                [newEntity fillWithDataDictionary:[keysWithEntities objectForKey: entityId]];
            }
            
            NSError *saveError = nil;
            [localMOC save:&saveError];
            if ( saveError ) {
                
                DEBUG_LOG(@"%@,%@",saveError.localizedDescription, saveError.userInfo);
            } else {
                
                [self saveContextAndParents:self.managedObjectContext];
            }
        }
    }];

    importOperation.completionBlock = ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:UpdateFinishedNotification object:self];
    };
    
    [self.backgroundQueue addOperation:importOperation];
}

#pragma mark - UIApplicationDelegateCoreDataProtocol methods
- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application,
            // although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            @throw [NSException exceptionWithName:kESLExceptionDidNotSaveMainContext
                                           reason:[error localizedFailureReason]
                                         userInfo:[error userInfo]];
        }
    }
}

- (void)saveMainContextAndWait {
    [self.managedObjectContext performBlockAndWait:^{
        [self saveContext];
    }];
}

- (void)saveContext:(NSManagedObjectContext *)managedobject {
    
    NSError *error;
    
    if (managedobject != nil) {
        
        if ([managedobject hasChanges]) {
            
            if (![managedobject save:&error]) {
                
                DEBUG_LOG(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
        }
    }
}

- (void)saveContextAndParents:(NSManagedObjectContext *)managedobject {
    [managedobject performBlockAndWait:^{
        [self saveContext:managedobject];
        if (managedobject.parentContext!=nil) {
            [managedobject.parentContext performBlockAndWait:^{
               [self saveContextAndParents:managedobject.parentContext];
            }];
        }
    }];
}

static char incrementalStoreProperty;

-(id)incrementalStore {
    return objc_getAssociatedObject(self, &incrementalStoreProperty);
}

-(void)setIncrementalStore:(id)incrementalStore {
    objc_setAssociatedObject(self, &incrementalStoreProperty,
                             incrementalStore, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    NSManagedObjectContext * returnContext=nil;
    
    if (!_useTestManagedObjectContext) {
        
        if (_managedObjectContext != nil) {
            return _managedObjectContext;
        }
        
        NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
        if (coordinator != nil) {
            _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            [_managedObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
            [_managedObjectContext setPersistentStoreCoordinator:coordinator];
        }
        returnContext=_managedObjectContext;
    } else {
        returnContext=[self testManagedObjectContext];
    }
    return returnContext;
}

- (NSPersistentStoreCoordinator *)testPersistentStoreCoordinator
{
    if (_testPersistentStoreCoordinator != nil) {
        return _testPersistentStoreCoordinator;
    }
    
    _testPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]
                                   initWithManagedObjectModel:[self managedObjectModel]];
    
    NSURL *storeUrl = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"test.sqlite"];
    
    NSError *error;
    if (![_testPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:nil error:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate.
        // You should not use this function in a shipping application, although it may be useful
        // during development. If it is not possible to recover from the error, display an alert
        // panel that instructs the user to quit the application by pressing the Home button.
        //
        
        // Typical reasons for an error here include:
        // The persistent store is not accessible
        // The schema for the persistent store is incompatible with current managed object model
        // Check the error message to determine what the actual problem was.
        //
		NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
		abort();
    }
    return _testPersistentStoreCoordinator;
}

- (NSManagedObjectContext *)testManagedObjectContext
{
    if (_testManagedObjectContext != nil) {
        return _testManagedObjectContext;
    }
    
    NSPersistentStoreCoordinator * coordinator=[self testPersistentStoreCoordinator];
    if (coordinator != nil) {
        _testManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_testManagedObjectContext setMergePolicy:NSErrorMergePolicy];
        [_testManagedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _testManagedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
#warning Use correct xcdatamodel file path
#define kCheckListDBName    @"EEIncrementalStore"
#define kCheckListDBExt    @"sqlite"

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    
    _managedObjectModel = [EEIncrementalStore model];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
    NSString * storeType=[EEIncrementalStore type];
    AFIncrementalStore *incrementalStore = (AFIncrementalStore *)[_persistentStoreCoordinator
                                                                  addPersistentStoreWithType:storeType
                                                                               configuration:nil
                                                                                         URL:nil
                                                                                     options:nil
                                                                                       error:nil];
    
    NSString * dbSqliteName=[kCheckListDBName stringByAppendingPathExtension:kCheckListDBExt];
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:dbSqliteName];
    
    // N.B: from iOS 7, Sqlite uses by default Write Ahead Logging
    // for now, use previous mode (journal_mode)
    NSDictionary *options = @{
                              NSInferMappingModelAutomaticallyOption : @(YES),
                              NSMigratePersistentStoresAutomaticallyOption: @(YES),
                              NSSQLitePragmasOption:@{ @"journal_mode" : @"DELETE" }
                              };
    
    NSError *error = nil;
    if (![incrementalStore.backingPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                          configuration:nil
                                                                                    URL:storeURL
                                                                                options:options
                                                                                  error:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        [[NSFileManager defaultManager] removeItemAtURL:storeURL error: &error];
        [incrementalStore.backingPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                         configuration:nil
                                                                                   URL:storeURL
                                                                               options:options
                                                                                 error:&error];
    }
    
    NSLog(@"SQLite URL: %@", [[self applicationDocumentsDirectory] URLByAppendingPathComponent:dbSqliteName]);
    
    self.incrementalStore=incrementalStore;
    
    return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

#pragma mark - Fetched Property

- (NSFetchedResultsController*)createFetchedResultControllerWithTemplate:(NSString *)templateName
                                               withSubstitutionVariables:(NSDictionary*)substitutionVariables
                                                  withSectionNameKeyPath:(NSString*)sectionNameKeyPath
                                                           withPredicate:(NSPredicate*)predicate
                                                               withCache:(NSString *) cacheName
                                                      andSortDescriptors:(NSArray*)sortDescriptors {
    
    NSFetchedResultsController *fetchedResultsController;
    NSManagedObjectModel *model = self.managedObjectModel;
    

    NSFetchRequest *fetchRequest = [model fetchRequestFromTemplateWithName:templateName
                                                     substitutionVariables:substitutionVariables];
    
    if( sortDescriptors ) {
        fetchRequest.sortDescriptors = sortDescriptors;
    }
    
    if( predicate ){
        fetchRequest.predicate = predicate;
    }
    NSManagedObjectContext * mObjectContext=[self managedObjectContext];

    fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                   managedObjectContext:mObjectContext
                                                                     sectionNameKeyPath:sectionNameKeyPath
                                                                              cacheName:cacheName];
    
    return fetchedResultsController;
}

#pragma mark - another fetch result controller method for GroupBy and Having clause
- (NSFetchedResultsController*)createFetchedResultControllerWithTemplate:(NSString *)templateName
                                               withSubstitutionVariables:(NSDictionary*)substitutionVariables
                                                  withSectionNameKeyPath:(NSString*)sectionNameKeyPath
                                                           withPredicate:(NSPredicate*)predicate
                                                               withCache:(NSString *) cacheName
                                                   withGroupByProperties:(NSArray *)groupByProperties
                                                     withHavingPredicate:(NSPredicate *)havingPredicate
                                                      andSortDescriptors:(NSArray*)sortDescriptors {
    
    NSFetchedResultsController *fetchedResultsController;
    NSManagedObjectModel *model = self.managedObjectModel;
    
    
    NSFetchRequest *fetchRequest = [model fetchRequestFromTemplateWithName:templateName
                                                     substitutionVariables:substitutionVariables];
    
    if( sortDescriptors ) {
        fetchRequest.sortDescriptors = sortDescriptors;
    }
    
    if( predicate ){
        fetchRequest.predicate = predicate;
    }
    
    if (groupByProperties) {
        [fetchRequest setPropertiesToGroupBy:groupByProperties];
    }
    
    if (havingPredicate) {
        [fetchRequest setHavingPredicate:havingPredicate];
    }

    NSManagedObjectContext * mObjectContext=[self managedObjectContext];
    
    fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                   managedObjectContext:mObjectContext
                                                                     sectionNameKeyPath:sectionNameKeyPath
                                                                              cacheName:cacheName];
    
    return fetchedResultsController;
}

- (NSFetchedResultsController*)createFetchedResultControllerWithFetchRequest:(NSFetchRequest *)fetchRequest
                                                      withSectionNameKeyPath:(NSString*)sectionNameKeyPath
                                                                    andCache:(NSString *) cacheName {
    
    NSFetchedResultsController *fetchedResultsController;
    
    
    NSManagedObjectContext * mObjectContext=[self managedObjectContext];
    
    fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                   managedObjectContext:mObjectContext
                                                                     sectionNameKeyPath:sectionNameKeyPath
                                                                              cacheName:cacheName];
    
    return fetchedResultsController;
}
@end
