//
//  ESSLViewController.h
//  AFISProva
//
//  Created by roberto avanzi on 28/06/13.
//  Copyright (c) 2013 Esselunga. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Department.h"

@interface ESSLViewController : UITableViewController

@property (nonatomic,strong) Department * dipartimento;
@property (nonatomic,strong) NSManagedObjectContext * managedObjectContext;

@end
