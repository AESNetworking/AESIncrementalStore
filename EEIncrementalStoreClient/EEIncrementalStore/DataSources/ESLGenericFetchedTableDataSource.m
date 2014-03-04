//
//  SLGenericFetchedTableDataSource.m
//  RubricaSede
//
//  Created by Luca Masini on 13/03/13.
//  Copyright (c) 2013 Luca Masini. All rights reserved.
//

#import "ESLGenericFetchedTableDataSource.h"
#import "ESLPersistenceManager.h"

#import <objc/runtime.h>

@interface ESLGenericFetchedTableDataSource()

@property (assign) id<NSFetchedResultsControllerDelegate> delegate;

@end

@implementation ESLGenericFetchedTableDataSource

@synthesize fetchedResultControllerDataSource = _fetchedResultControllerDataSource;

- (void) assignDelegate:(id<NSFetchedResultsControllerDelegate>) delegate andCellFactory:(id<ESLTableViewCellProtocol>) factory {

    if( self ) {
        self.delegate = delegate;
        self.factory = factory;
    }
}

#pragma mark - Fetch Request property accessors

- (NSFetchedResultsController*)fetchedResultControllerDataSource {

    if(_fetchedResultControllerDataSource==nil ) {
        
        ESLPersistenceManager *serviceManager = [ESLPersistenceManager sharedInstance];
        
        _fetchedResultControllerDataSource = [self createFetchedResultControllerWithTemplate:serviceManager];
        _fetchedResultControllerDataSource.delegate=self.delegate;
        
		NSError * error;
        
        if( ![_fetchedResultControllerDataSource performFetch: &error] ) {
            // Stamperemo qualcosa di intelligente
			DEBUG_LOG(@"%@", error);
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
    
    return cell;
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
@end
