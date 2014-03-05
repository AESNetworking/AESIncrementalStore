// CheckInsViewController.m
//
// Copyright (c) 2012 Mattt Thompson (http://mattt.me)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


#import <math.h>
#import "Department.h"
#import "Employee.h"
#import "BusinessSmartphone.h"
#import "BusinessTablet.h"
#import "ESSLViewController.h"
#import "AFISProvaIncrementalStore.h"
#import <QuartzCore/QuartzCore.h>
#import "UIApplicationDelegateCoreDataProtocol.h"
#import "AFISProvaViewController.h"
#import "AFISProvaAPIClient.h"
#import "ESLPersistenceManager.h"

@interface AFISProvaViewController () <NSFetchedResultsControllerDelegate> {
    NSFetchedResultsController *_fetchedResultsController;
    BOOL _flagEdit;
    UINib * _viewStateNib;
    NSOperationQueue * _deletedQueue;
}
@end


@implementation AFISProvaViewController

-(void)refreshTableView {
    [self.tableView reloadData];
    if (self.refreshControl.refreshing) {
        [self.refreshControl endRefreshing];
    }
}

#pragma mark - didFetchRemoteValues method
#if 0
- (void)alignBackAndMainContextWithObjectIDs:(NSArray *)managedObjectIDs {
    id<UIApplicationDelegateCoreDataProtocol> delegate=(id<UIApplicationDelegateCoreDataProtocol>)[[UIApplication sharedApplication] delegate];
    
    NSManagedObjectContext * mainContext=[delegate managedObjectContext];
    NSManagedObjectContext * backContext=[(AFIncrementalStore *)[delegate incrementalStore] backingManagedObjectContext];
    for (NSManagedObjectID * objectID in managedObjectIDs) {
        NSLog(@"object on DB = %@\n", [[objectID URIRepresentation] absoluteString]);
    }
}
#endif

-(void)didFetchRemoteValues:(NSNotification *)notification {
    NSManagedObjectContext * mObject=notification.object;
    NSDictionary * userInfo=notification.userInfo;
    NSManagedObjectContext * mainContext=[(id)[[UIApplication sharedApplication] delegate] managedObjectContext];
    if (mObject == mainContext) {
        NSError * error=[userInfo objectForKey:AFIncrementalStoreFetchSaveRequestErrorKey];
        if (error) {
            UIAlertView * alertView=[[UIAlertView alloc] initWithTitle:@"Errore Allineamento" message:@"Errore durante l'allineamento del DB remoto. Riprova successivamente. Puoi comunque continuare a modificare i dati in locale" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
        } else {
            //NSArray * managedObjectIDs=[userInfo objectForKey:AFIncrementalStoreFetchedObjectIDsKey];
            //[self alignBackAndMainContextWithObjectIDs:managedObjectIDs];
            [self performSelector:@selector(refreshTableView) withObject:nil afterDelay:0.2];
        }
    }
    
    if (self.refreshControl.refreshing) {
        [self.refreshControl endRefreshing];
    }
}

#pragma mark - didFetchRemoteValues method
-(void)didSaveRemoteValues:(NSNotification *)notification {
    static NSDate * lasttimestamp;
    NSManagedObjectContext * mObject=notification.object;
    NSDictionary * userInfo=notification.userInfo;
    NSManagedObjectContext * mainContext=[(id)[[UIApplication sharedApplication] delegate] managedObjectContext];
    if (mObject == mainContext) {
        NSError * error=[userInfo objectForKey:AFIncrementalStoreFetchSaveRequestErrorKey];
        if (error) {
            if ([[NSDate date] timeIntervalSinceDate:lasttimestamp] < 1  && lasttimestamp) {
                return;
            }
                UIAlertView * alertView=[[UIAlertView alloc] initWithTitle:@"Errore Allineamento" message:@"Errore durante l'allineamento del DB remoto. Riprova successivamente. Puoi comunque continuare a modificare i dati in locale" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alertView show];
                lasttimestamp=[NSDate date];

        } else {
            [self performSelector:@selector(refreshTableView) withObject:nil afterDelay:0.2];
        }
    }
}

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Department", nil);
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Department"];
    fetchRequest.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"modified" ascending:NO]];
    fetchRequest.returnsObjectsAsFaults = NO;
    fetchRequest.includesPendingChanges = NO;
    
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:[[ESLPersistenceManager sharedInstance] managedObjectContext] sectionNameKeyPath:nil cacheName:nil];
    _fetchedResultsController.delegate = self;
    [_fetchedResultsController performFetch:nil];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refetchData:) forControlEvents:UIControlEventValueChanged];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:AFIncrementalStoreContextDidSaveRemoteValues object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [self didSaveRemoteValues:note];
    }];
    _deletedQueue=[[NSOperationQueue alloc] init];
    [_deletedQueue setMaxConcurrentOperationCount:1];

    _flagEdit=NO;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(checkIn:)];
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit    target:self action:@selector(editCheckIn:)];

    _viewStateNib=[UINib nibWithNibName:@"viewAlignment" bundle:[NSBundle mainBundle]];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
}

#pragma mark - IBAction

- (void)refetchData:(id)sender {
    _fetchedResultsController.fetchRequest.resultType = NSManagedObjectResultType;
    [_fetchedResultsController performFetch:nil];
}

-(void)createDepartment {
    NSManagedObjectContext * mObjectContext=_fetchedResultsController.managedObjectContext;
    Department * dipartimento=[NSEntityDescription insertNewObjectForEntityForName:@"Department" inManagedObjectContext:mObjectContext];
    dipartimento.codiceIdentificativo=@12345;
    dipartimento.nome=@"Sistemi Informativi";
    dipartimento.department_id=[NSManagedObject localResourceIdentifier];
    //dipartimento.timestamp=[NSDate date];
    
    Employee * employee1=[NSEntityDescription insertNewObjectForEntityForName:@"Employee" inManagedObjectContext:mObjectContext];
    employee1.nome=@"Roberto";
    employee1.cognome=@"Avanzi";
    employee1.dipendente=@0;
    employee1.livello=@0;
    employee1.employee_id=[NSManagedObject localResourceIdentifier];
    //employee1.timestamp=[NSDate date];
    
    Employee * employee2=[NSEntityDescription insertNewObjectForEntityForName:@"Employee" inManagedObjectContext:mObjectContext];
    employee2.nome=@"Luca";
    employee2.cognome=@"Masini";
    employee2.dipendente=@1;
    employee2.livello=@1;
    employee2.employee_id=[NSManagedObject localResourceIdentifier];
    
    //employee2.timestamp=[NSDate date];
    
    Employee * employee3=[NSEntityDescription insertNewObjectForEntityForName:@"Employee" inManagedObjectContext:mObjectContext];
    employee3.nome=@"Rosanna";
    employee3.cognome=@"Rinaldi";
    employee3.dipendente=@0;
    employee3.livello=@2;
    employee3.employee_id=[NSManagedObject localResourceIdentifier];
    //employee3.timestamp=[NSDate date];
    
    Employee * employee4=[NSEntityDescription insertNewObjectForEntityForName:@"Employee" inManagedObjectContext:mObjectContext];
    employee4.nome=@"Giovanni";
    employee4.cognome=@"Tarducci";
    employee4.dipendente=@0;
    employee4.livello=@3;
    employee4.employee_id=[NSManagedObject localResourceIdentifier];
    //employee4.timestamp=[NSDate date];
    
    {
    
    dipartimento.employees=[NSSet setWithObjects:employee1, employee2, employee3, employee4, nil];
    }
    BusinessSmartphone  * smartphone=[NSEntityDescription insertNewObjectForEntityForName:@"BusinessSmartphone" inManagedObjectContext:mObjectContext];
    {
    
    smartphone.modello=@"iPhone 3GS";
    smartphone.tipo=@"1";
    smartphone.businesssmartphone_id=[NSManagedObject localResourceIdentifier];
    smartphone.employee=employee1;
    //smartphone.timestamp=[NSDate date];
    
    
    }
    BusinessTablet  * smarttablet=[NSEntityDescription insertNewObjectForEntityForName:@"BusinessTablet" inManagedObjectContext:mObjectContext];
    {
    
    smarttablet.modello=@"iPad 0";
    smarttablet.tipo=@"2";
    smarttablet.businesstablet_id=[NSManagedObject localResourceIdentifier];
    smarttablet.employee=employee2;
    //smarttablet.timestamp=[NSDate date];
    
    }
}

- (void)checkIn:(id)sender {
    
    [self createDepartment];
    NSError *error = nil;
    if (![_fetchedResultsController.managedObjectContext save:&error]) {
        NSLog(@"Error: %@", error);
    }
}

-(IBAction)editCheckIn:(id)sender {
    _flagEdit=!_flagEdit;
    [self.tableView setEditing:_flagEdit animated:YES];
    UIBarButtonSystemItem itemButton;
    if (_flagEdit) {
        itemButton=UIBarButtonSystemItemDone;
    } else {
        itemButton=UIBarButtonSystemItemEdit;
    }
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:itemButton
                                                                                        target:self action:@selector(editCheckIn:)];

    
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[_fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[_fetchedResultsController sections] objectAtIndex:section] numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        UIViewController * fakeView=[[UIViewController alloc] init];
        [_viewStateNib instantiateWithOwner:fakeView options:nil];
        cell.accessoryView=fakeView.view;
        cell.accessoryView.backgroundColor=[UIColor redColor];
        cell.accessoryView.layer.cornerRadius=10.f;
        cell.accessoryView.layer.masksToBounds=YES;
    }
    
    Department *dipartimento = (Department *)[_fetchedResultsController objectAtIndexPath:indexPath];
    NSLog(@"dipartimento con versione = %ld", [[dipartimento version] longValue]);
    cell.textLabel.text = [[dipartimento codiceIdentificativo] stringValue];
    cell.detailTextLabel.numberOfLines=0;
    cell.detailTextLabel.text=[NSString stringWithFormat:@"nome=%@\ndipendente=%@\ndata creazione=%@\ndata modifica=%@\n",
    [dipartimento nome], [[[dipartimento employees] anyObject] nome], [[dipartimento created] description], [[dipartimento modified] description]];
    NSLog(@"dipartimento af_aligned = %@",dipartimento.af_aligned);
    if ([dipartimento.af_aligned isEqualToString:@"1"]) {
        [UIView animateWithDuration:.2f animations:^{
            cell.accessoryView.backgroundColor=[UIColor greenColor];
        }];
    } else {
        [UIView animateWithDuration:.2f animations:^{
            cell.accessoryView.backgroundColor=[UIColor redColor];
        }];
    }
    return cell;
}

#pragma  mark - TableView Data Source
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	
	return TRUE;
	
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 140.f;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (editingStyle) {
		case UITableViewCellEditingStyleDelete:
        {
            Department * dipartimento=[_fetchedResultsController objectAtIndexPath:indexPath];
            [self deleteDipartimento:dipartimento];
        }
            break;
        default:
            break;
    }
}

-(void)deleteDipartimento:(NSManagedObject *)object {
    NSManagedObjectContext * mObjectContext=_fetchedResultsController.managedObjectContext;
    
    [mObjectContext deleteObject:object];
    
    NSError * error=nil;
    if (![_fetchedResultsController.managedObjectContext save:&error]) {
        NSLog(@"Error: %@", error);
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    Department *dipartimento = (Department *)[_fetchedResultsController objectAtIndexPath:indexPath];
    NSLog(@"Selezionato dipartimento con version: %ld", [[dipartimento version] longValue]);
    NSLog(@"dipartimento af_aligned = %@",dipartimento.af_aligned);
#if 1
    ESSLViewController * detailCtrl=[[ESSLViewController alloc] initWithNibName:nil bundle:nil];
    detailCtrl.managedObjectContext=_fetchedResultsController.managedObjectContext;
    detailCtrl.dipartimento=dipartimento;
    [self.navigationController pushViewController:detailCtrl animated:YES];
#else
#if 1
    static int nomeDepartment;
    nomeDepartment=!nomeDepartment;
    dipartimento.nome=(nomeDepartment)?@"Sistemi Agricoli":@"Sistemi Gestionali";
    //[self createDepartment];
    
#else
    NSMutableSet * mutableEmployees=[NSMutableSet setWithSet:dipartimento.employees];
    [mutableEmployees removeObject:[mutableEmployees anyObject]];
    dipartimento.employees=mutableEmployees;
#endif
    NSError * error=nil;
    if (![_fetchedResultsController.managedObjectContext save:&error]) {
        NSLog(@"Error: %@", error);
    }
    [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]
             withRowAnimation:UITableViewRowAnimationAutomatic];
#endif
}

#pragma mark - NSFetchedResultsControllerDelegate
#pragma mark - NSFetchedResultController delegate methods
- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type {
    
    switch(type) {
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
            
    }
    
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    if (type == NSFetchedResultsChangeDelete) {
        // Delete row from tableView.
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
    }
    if (type == NSFetchedResultsChangeInsert) {
        // insert row in tableView.
        [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

@end