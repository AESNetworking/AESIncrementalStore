//
//  BusinessTablet.h
//  AFISProva
//
//  Created by roberto avanzi on 03/09/13.
//  Copyright (c) 2013 Esselunga. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Employee;

@interface BusinessTablet : NSManagedObject

@property (nonatomic, retain) NSString * businesstablet_id;
@property (nonatomic, retain) NSDate * created;
@property (nonatomic, retain) NSDate * dataAcquisto;
@property (nonatomic, retain) NSString * modello;
@property (nonatomic, retain) NSDate * modified;
@property (nonatomic, retain) NSString * tipo;
@property (nonatomic, retain) NSNumber * version;
@property (nonatomic, retain) Employee *employee;

@end
