//
//  ESSLViewController.m
//  AFISProva
//
//  Created by roberto avanzi on 28/06/13.
//  Copyright (c) 2013 Esselunga. All rights reserved.
//

#import "ESSLViewController.h"
#import "UIApplicationDelegateCoreDataProtocol.h"
#import "Employee.h"
#import "BusinessSmartphone.h"
#import "BusinessTablet.h"

@interface ESSLViewController ()<UITextFieldDelegate>

@property (nonatomic,retain) UINib * nibCell;
@property (nonatomic,retain) NSString * nomeDipartimento;
@property (nonatomic,retain) NSArray * relationshipNames;

@end

@implementation ESSLViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];


    //self.nibCell=[UINib nibWithNibName:@"detailTableViewCell" bundle:[NSBundle mainBundle]];
    
    _relationshipNames=[[[_dipartimento entity] relationshipsByName] allKeys];
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{

    // Return the number of sections.
    return [_relationshipNames count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [[_dipartimento valueForKey:[_relationshipNames objectAtIndex:section]] count];
}


-(IBAction)objectSave:(id)sender {

    [_managedObjectContext performBlockAndWait:^{
        [_managedObjectContext save:nil];
    }];
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if ((![_nomeDipartimento isEqualToString:textField.text]) && textField.text) {
        self.dipartimento.nome=textField.text;
        NSLog(@"dipartimento aggiornato = %@\n", self.dipartimento);
       [self performSelector:@selector(objectSave:) withObject:nil afterDelay:0.1];
        
    }
    [textField resignFirstResponder];
    return YES;
}


#pragma mark - UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 220.f;
}

#define kTableViewCellUITextField 2
#define kTableViewCellUIButton 3
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString * relationshipName=[_relationshipNames objectAtIndex:indexPath.section];
    NSSet * relationship=[_dipartimento valueForKey:relationshipName];
    NSManagedObject * mObject=[[relationship allObjects] objectAtIndex:indexPath.row];
    static NSString *CellIdentifier = @"CellDetailView";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.numberOfLines=0;
        cell.detailTextLabel.numberOfLines=0;
    }
    
    NSString * stringDisplay=nil, * localDisplay=nil;
    if ([mObject isKindOfClass:[Employee class]]) {
        Employee * employee=(Employee *)mObject;
        stringDisplay=[NSString stringWithFormat:@"nome = %@, cognome = %@, created = %@",
                       employee.nome, employee.cognome, [employee.created description]];
        
        NSArray * relationshipNames=[[[employee entity] relationshipsByName] allKeys];
        NSSet * relationshipObjects;
        NSManagedObject * childObject=nil;
        for (NSString * relationshipName in relationshipNames) {
            relationshipObjects=[employee valueForKey:relationshipName];
            if ([[[[employee entity] relationshipsByName] objectForKey:relationshipName] isToMany]) {
                for (childObject in relationshipObjects) {
                    if ([childObject isKindOfClass:[BusinessSmartphone class]]) {
                        BusinessSmartphone * smartphone=(BusinessSmartphone *)childObject;
                        localDisplay=[NSString stringWithFormat:@"\nRelazione = %@\n tipo = %@, modello = %@, created = %@",
                                       [relationshipName uppercaseString], smartphone.tipo, smartphone.modello, [smartphone.created description]];
                        stringDisplay=[stringDisplay stringByAppendingString:localDisplay];
                    } else if ([mObject isKindOfClass:[BusinessTablet class]]) {
                            BusinessTablet * tablet=(BusinessTablet *)mObject;
                            localDisplay=[NSString stringWithFormat:@"\nRelazione = %@\ntipo = %@, modello = %@, created = %@",
                                          [relationshipName uppercaseString], tablet.tipo, tablet.modello, [tablet.created description]];
                        stringDisplay=[stringDisplay stringByAppendingString:localDisplay];
                    }
                }
            }
        }
        
    } 
    cell.textLabel.text=relationshipName;
    cell.detailTextLabel.text=stringDisplay;
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}

@end
