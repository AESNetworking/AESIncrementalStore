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

@protocol ESLGenericFetchedTableDataSourceProtocol<NSObject>

@optional
-(NSFetchedResultsController *) createFetchedResultControllerWithTemplate: (ESLPersistenceManager *)serviceManager;
- (void) populateCell:(UITableViewCell* )cell withModel: (id) modelObject;
- (NSString *) cellIdentifier;

@end

@protocol ESLCellTagCalculator<NSObject>

- (NSInteger) calculateTagForCellAtIndexPath:(NSIndexPath*)indexPath;

@end

@protocol ESLGenericFetchedChangeContextDelegate;

@interface ESLGenericFetchedTableDataSource : NSObject<UITableViewDataSource, ESLGenericFetchedTableDataSourceProtocol, ESLCellTagCalculator>

@property (nonatomic,assign) id<ESLTableViewCellProtocol>factory;

@property (nonatomic,retain,readonly) NSFetchedResultsController* fetchedResultControllerDataSource;

- (void) assignDelegate:(id<NSFetchedResultsControllerDelegate>) delegate andCellFactory:(id<ESLTableViewCellProtocol>) factory;

@property (nonatomic,assign) NSInteger selectedRow;

@property (nonatomic,strong,readonly) NSString * fetchedEntityName;

@property (nonatomic,assign) id<ESLGenericFetchedChangeContextDelegate> contextDelegate;

-(void)setSelecteRowOnManagedObject:(NSManagedObject *)object;

@end

@protocol ESLGenericFetchedChangeContextDelegate <NSObject>

-(void)genericFetchedTableDataSourceWillChangeContent:(ESLGenericFetchedTableDataSource *)fetchTableDataSource;
-(void)genericFetchedTableDataSourceDidChangeContent:(ESLGenericFetchedTableDataSource *)fetchTableDataSource;
@optional
-(void)genericFetchedTableDataSourceDidFailFetchContent:(ESLGenericFetchedTableDataSource *)fetchTableDataSource
                                              withError:(NSError *)error;
-(void)genericFetchedTableDataSourceDidFailSaveContent:(ESLGenericFetchedTableDataSource *)fetchTableDataSource
                                             withError:(NSError *)error;

@end
