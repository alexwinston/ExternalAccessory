//
//  NSMutableArray+Queue.h
//  ExternalAccessory
//
//  Created by Alex Winston on 8/16/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSMutableArray (Queue)
- (id)dequeue;
- (void)enqueue:(id)anObject;
@end
