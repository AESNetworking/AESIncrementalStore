//
//  SLGenericFetchedTableDataSource.m
//  RubricaSede
//
//  Created by Luca Masini on 13/03/13.
//  Copyright (c) 2013 Luca Masini. All rights reserved.
//

#import "ESLGenericFetchedTableDataSource.h"
#import "ESLPersistenceManager.h"
#import "EEIncrementalStore.h"
#import <objc/runtime.h>

@interface ESLGenericFetchedTableDataSource()

@property (assign) id<NSFetchedResultsControllerDelegate> delegate;
@property (nonatomic,strong) id willFetchObserver;
@property (nonatomic,strong) id didFetchObserver;
@property (nonatomic,strong) id willSaveObserver; // not used now
@property (nonatomic,strong) id didSaveObserver;

@end

@implementation ESLGenericFetchedTableDataSource

@synthesize fetchedResultControllerDataSource = _fetchedResultControllerDataSource;

-(id)init {
    if (self=[super init]) {
        self.selectedRow=-1;
    }
    return self;
}


-(void)willFetchObserver:(NSNotification *)note {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSFetchRequest * fetchRequest=[note.userInfo objectForKey:AFIncrementalStorePersistentStoreRequestKey];
        if ([[fetchRequest entityName] isEqualToString:self.fetchedEntityName]) {
            if ([_contextDelegate respondsToSelector:@selector(genericFetchedTableDataSourceWillChangeContent:)]) {
                [_contextDelegate genericFetchedTableDataSourceWillChangeContent:self];
            }
        }
    }];
}

-(void)didFetchObserver:(NSNotification *)note {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSFetchRequest * fetchRequest=[note.userInfo objectForKey:AFIncrementalStorePersistentStoreRequestKey];
        NSError * error=[note.userInfo objectForKey:AFIncrementalStoreFetchSaveRequestErrorKey];
        if ([[fetchRequest entityName] isEqualToString:self.fetchedEntityName]) {
            if (!error) {
                if ([_contextDelegate respondsToSelector:@selector(genericFetchedTableDataSourceDidChangeContent:)]) {
                    [_contextDelegate genericFetchedTableDataSourceDidChangeContent:self];
                }
            } else {
                if ([_contextDelegate respondsToSelector:@selector(genericFetchedTableDataSourceDidFailFetchContent:withError:)]) {
                    [_contextDelegate genericFetchedTableDataSourceDidFailFetchContent:self withError:error];
                }
            }
        }
    }];
}

-(void)didSaveObserver:(NSNotification *)note {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSError * error=[note.userInfo objectForKey:AFIncrementalStoreFetchSaveRequestErrorKey];
        if (!error) {
            if ([_contextDelegate respondsToSelector:@selector(genericFetchedTableDataSourceDidChangeContent:)]) {
                [_contextDelegate genericFetchedTableDataSourceDidChangeContent:self];
            }
        } else {
            if ([_contextDelegate respondsToSelector:@selector(genericFetchedTableDataSourceDidFailSaveContent:withError::)]) {
                [_contextDelegate genericFetchedTableDataSourceDidFailSaveContent:self withError:error];
            }
        }
    }];
}

- (void) assignDelegate:(id<NSFetchedResultsControllerDelegate>) delegate andCellFactory:(id<ESLTableViewCellProtocol>) factory {
    
    if( self ) {
        self.delegate = delegate;
        self.factory = factory;
        NSNotificationCenter * defaultCenter=[NSNotificationCenter defaultCenter];
        [defaultCenter addObserver:self selector:@selector(willFetchObserver:) name:AFIncrementalStoreContextWillFetchRemoteValues object:nil];
        [defaultCenter addObserver:self selector:@selector(didFetchObserver:) name:AFIncrementalStoreContextDidFetchRemoteValues object:nil];
        [defaultCenter addObserver:self selector:@selector(didSaveObserver:) name:AFIncrementalStoreContextDidSaveRemoteValues object:nil];
    }
}

#pragma mark - Fetch Request property accessors

- (NSFetchedResultsController*)fetchedResultControllerDataSource {
    
    if(_fetchedResultControllerDataSource==nil ) {
        
        ESLPersistenceManager *serviceManager = [ESLPersistenceManager sharedInstance];
        
        _fetchedResultControllerDataSource = [self createFetchedResultControllerWithTemplate:serviceManager];
        _fetchedResultControllerDataSource.delegate=self.delegate;
        
        // nota, devo per forza lasciare questo fetch nel generic data source ed
        // utilizzarlo anche se sono offline, altrimenti non carica niente ...
        NSError * error=nil;
        if (![self.fetchedResultControllerDataSource performFetch:&error]) {
            NSLog(@"Fetch error %@, %@", error, [error userInfo]);
        }
        
    }
    
    return _fetchedResultControllerDataSource;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	NSInteger count = [[self.fetchedResultControllerDataSource sections] count];
    
    // DEBUG_LOG(@"numberOfSectionsInTableView: %d", count);
    
    return count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = 0;
    //id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultControllerDataSource sections] objectAtIndex:section];
	// sometimes crashed, may be some refs was nil? add more control:
    
	NSArray *sections = [self.fetchedResultControllerDataSource sections];
	if ([sections count]>0) // if nil count is zero...
        {
		id <NSFetchedResultsSectionInfo> sectionInfo = [sections objectAtIndex:section];
		count = [sectionInfo numberOfObjects];
        }
	else
        {
		DEBUG_LOG(@"numberOfRows: %ld;  InSection: %ld, ", (long)section, (long)count);
        }
    // DEBUG_LOG(@"numberOfRows: %d;  InSection: %d, ", count, section);
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.factory dequeueReusableCellWithIdentifier:self.cellIdentifier forIndexPath:indexPath withTable:tableView];
    NSUInteger row=indexPath.row;
    
    cell.tag = [self calculateTagForCellAtIndexPath:indexPath];
    
    UIFont * bodylineFont=[UIFont systemFontOfSize:14.0];
    UIFont * headlineFont=[UIFont boldSystemFontOfSize:12.0];
    
    Method value=class_getClassMethod([UIFont class], @selector(preferredFontForTextStyle:));
    
    if (value!=NULL) {
        bodylineFont=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        headlineFont=[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    }
    cell.textLabel.font=headlineFont;
    cell.detailTextLabel.font=bodylineFont;
    // Configure the cell...
    id modelObject = [self.fetchedResultControllerDataSource objectAtIndexPath:indexPath];
    
    [self populateCell:cell withModel:modelObject];
    
    if (self.selectedRow==row) {
        cell.accessoryType=UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType=UITableViewCellAccessoryNone;
    }
    
    return cell;
}
-(void)setSelectedRow:(NSInteger)selectedRow {
    _selectedRow=selectedRow;
}

-(void)setSelecteRowOnManagedObject:(NSManagedObject *)object {
    
    if (object!=nil) {
        NSIndexPath * selectedIndexPath = [self.fetchedResultControllerDataSource indexPathForObject:object];
        if (selectedIndexPath!=nil) {
            self.selectedRow=selectedIndexPath.row;
        }
    }
}
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return self.fetchedResultControllerDataSource.sectionIndexTitles;
}

- (NSInteger) calculateTagForCellAtIndexPath:(NSIndexPath*)indexPath {
    return indexPath.section*MaxRows+indexPath.row;
}

/* Roberto start aggiunta gestione titoli sezioni all'interno del data source */
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSUInteger nbrSections=[self.fetchedResultControllerDataSource.sectionIndexTitles count];
    if (section< nbrSections) {
        return [self.fetchedResultControllerDataSource.sectionIndexTitles
				objectAtIndex:section];
    }
    NSLog(@"tableview in titleForHeaderInSection = %@, %ld", tableView, (long)section);
    return nil;
}
/* Roberto stop */

-(void)dealloc {
    
    DEBUG_LOG(@"dealloc on generic fetch data source");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

@end
