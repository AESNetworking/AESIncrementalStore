//
//  SLPersistenceManager.h
//  RubricaSede
//
//  Created by Luca Masini on 01/03/13.
//  Copyright (c) 2013 Luca Masini. All rights reserved.
//

#import "CoreDataIncrementalStoreProtocol.h"
#import "NSManagedObjectContext+saveContext.h"
#import "ESLGenericFetchedTableDataSource.h"

static NSString * const NewNSDataNotification       = @"NewNSDataNotification";
static NSString * const NewNSArrayNotification      = @"NewNSArrayNotification";
static NSString * const NoNewNSArrayNotification    = @"NoNewNSArrayNotification";

extern NSString * kESLExceptionDidNotSaveMainContext;

@interface ESLPersistenceManager : NSObject<CoreDataIncrementalStoreProtocol>

+ (ESLPersistenceManager*)sharedInstance;

@property (nonatomic,strong)  NSManagedObjectContext * testManagedObjectContext;
@property (nonatomic,strong)  NSPersistentStoreCoordinator  * testPersistentStoreCoordinator;
@property (nonatomic) BOOL useTestManagedObjectContext;
@property (nonatomic,strong) NSOperationQueue *offlineOperationQueue;

- (NSFetchedResultsController*)createFetchedResultControllerWithTemplate:(NSString*)templateName
                                               withSubstitutionVariables:(NSDictionary*)substitutionVariables
                                                  withSectionNameKeyPath:(NSString*)sectionNameKeyPath
                                                           withPredicate:(NSPredicate*)predicate
                                                               withCache:(NSString*) cacheName
                                                      andSortDescriptors:(NSArray*)sortDescriptors;

- (NSFetchedResultsController*)createFetchedResultControllerWithTemplate:(NSString *)templateName
                                               withSubstitutionVariables:(NSDictionary*)substitutionVariables
                                                  withSectionNameKeyPath:(NSString*)sectionNameKeyPath
                                                           withPredicate:(NSPredicate*)predicate
                                                               withCache:(NSString *) cacheName
                                                   withGroupByProperties:(NSArray *)groupByProperties
                                                     withHavingPredicate:(NSPredicate *)havingPredicate
                                                      andSortDescriptors:(NSArray*)sortDescriptors;

- (NSFetchedResultsController*)createFetchedResultControllerWithFetchRequest:(NSFetchRequest *)fetchRequest
                                                      withSectionNameKeyPath:(NSString*)sectionNameKeyPath
                                                                    andCache:(NSString *)cacheName;

- (void)warnMeWhenMainContextIsSaved:(id)observer usingThisSelector:(SEL)aSelector;

-(void)executeFetchOnGenericDataSource:(ESLGenericFetchedTableDataSource *)dataSource;
-(void)executeRollback;

@end
