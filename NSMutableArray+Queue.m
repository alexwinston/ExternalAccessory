//
//  NSMutableArray+Queue.m
//  ExternalAccessory
//
//  Created by Alex Winston on 8/16/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "NSMutableArray+Queue.h"


@implementation NSMutableArray (Queue)

- (id) dequeue {
	if ([self count] == 0)
		return nil;
	
	id headObject = [self objectAtIndex:0];
    if (headObject != nil) {
        [[headObject retain] autorelease]; // so it isn't dealloc'ed on remove
        
		[self removeObjectAtIndex:0];
    }

    return headObject;
}

- (void) enqueue:(id)anObject {
    [self addObject:anObject];
}

@end
