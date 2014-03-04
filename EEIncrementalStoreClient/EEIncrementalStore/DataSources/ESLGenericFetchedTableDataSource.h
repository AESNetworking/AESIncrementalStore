//
//  SLGenericFetchedTableDataSource.h
//  RubricaSede
//
//  Created by Luca Masini on 13/03/13.
//  Copyright (c) 2013 Luca Masini. All rights reserved.
//

#import "ESLTableViewCellProtocol.h"

static NSInteger const MaxRows = 10000;
static NSInteger const CellOffset = 1000000;

@class ESLPersistenceManager;

@protocol ESLGenericFetchedTableDataSourceProtocol

@optional
-(NSFetchedResultsController *) createFetchedResultControllerWithTemplate: (ESLPersistenceManager *)serviceManager;
- (void) populateCell:(UITableViewCell* )cell withModel: (id) modelObject;
- (NSString *) cellIdentifier;

@end

@protocol ESLCellTagCalculator

- (NSInteger) calculateTagForCellAtIndexPath:(NSIndexPath*)indexPath;

@end

@interface ESLGenericFetchedTableDataSource : NSObject<UITableViewDataSource, ESLGenericFetchedTableDataSourceProtocol, ESLCellTagCalculator>

@property (nonatomic,assign) id<ESLTableViewCellProtocol>factory;

@property (nonatomic,retain,readonly) NSFetchedResultsController* fetchedResultControllerDataSource;

- (void) assignDelegate:(id<NSFetchedResultsControllerDelegate>) delegate andCellFactory:(id<ESLTableViewCellProtocol>) factory;

@end
