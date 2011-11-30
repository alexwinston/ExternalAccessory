//
//  EAAccessoryInternal.m
//  ExternalAccessory
//
//  Created by Alex Winston on 8/13/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "EAAccessoryInternal.h"
#import "EAAccessory.h"


@implementation EAAccessoryInternal

@synthesize delegate=_delegate;
@synthesize protocols=_protocols;
@synthesize hardwareRevision=_hardwareRevision;
@synthesize firmwareRevision=_firmwareRevision;
@synthesize serialNumber=_serialNumber;
@synthesize modelNumber=_modelNumber;
@synthesize name=_name;
@synthesize manufacturer=_manufacturer;
@synthesize connectionID=_connectionID;
@synthesize connected=_connected;

- (id)init {
	if( !(self=[super init]) )
		return nil;
	
	return self;
}

- (void)release {
	[super dealloc];
}

@end
