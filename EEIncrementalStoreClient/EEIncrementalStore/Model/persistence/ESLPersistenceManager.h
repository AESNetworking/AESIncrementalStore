//
//  SLPersistenceManager.h
//  RubricaSede
//
//  Created by Luca Masini on 01/03/13.
//  Copyright (c) 2013 Luca Masini. All rights reserved.
//

#import "CoreDataIncrementalStoreProtocol.h"

static NSString * const NewNSDataNotification       = @"NewNSDataNotification";
static NSString * const NewNSArrayNotification      = @"NewNSArrayNotification";
static NSString * const NoNewNSArrayNotification    = @"NoNewNSArrayNotification";

extern NSString * kESLExceptionDidNotSaveMainContext;

@interface ESLPersistenceManager : NSObject<CoreDataIncrementalStoreProtocol>

+ (ESLPersistenceManager*)sharedInstance;

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
- (void)saveContextAndParents:(NSManagedObjectContext *)managedobject;
- (void)saveMainContextAndWait;

- (void)warnMeWhenMainContextIsSaved:(id)observer usingThisSelector:(SEL)aSelector;

@property (nonatomic,strong)  NSManagedObjectContext * testManagedObjectContext;
@property (nonatomic,strong)  NSPersistentStoreCoordinator  * testPersistentStoreCoordinator;
@property (nonatomic) BOOL useTestManagedObjectContext;

@end
