//
//  Department.h
//  AFISProva
//
//  Created by Roberto Avanzi on 07/08/13.
//  Copyright (c) 2013 Esselunga. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Employee;

@interface Department : NSManagedObject

@property (nonatomic, retain) NSNumber * codiceIdentificativo;
@property (nonatomic, retain) NSDate * created;
@property (nonatomic, retain) NSString * department_id;
@property (nonatomic, retain) NSDate * modified;
@property (nonatomic, retain) NSString * nome;
@property (nonatomic, retain) NSNumber * version;
@property (nonatomic, retain) NSSet *employees;
@end

@interface Department (CoreDataGeneratedAccessors)

- (void)addEmployeesObject:(Employee *)value;
- (void)removeEmployeesObject:(Employee *)value;
- (void)addEmployees:(NSSet *)values;
- (void)removeEmployees:(NSSet *)values;

@end
