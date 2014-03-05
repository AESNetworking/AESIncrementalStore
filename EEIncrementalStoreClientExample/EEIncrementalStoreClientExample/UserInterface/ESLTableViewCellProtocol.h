//
//  ESLTableViewCellProtocol.h
//  RubricaSede
//
//  Created by Luca Masini on 13/03/13.
//  Copyright (c) 2013 Luca Masini. All rights reserved.
//

@protocol ESLTableViewCellProtocol <NSObject>

- (UITableViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath withTable:(UITableView*) tableView;

@end
