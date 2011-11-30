//
//  EAAccessory.m
//  ExternalAccessory
//
//  Created by Alex Winston on 8/13/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "EAAccessory.h"
#import "EAAccessoryInternal.h"


@implementation EAAccessory

- (id)_initWithAccessory:(EAAccessoryInternal *)accessory {
	if( !(self=[super init]) )
		return nil;
	
	_internal = [accessory retain];
	
	return self;
}

- (void)_setConnected:(BOOL)connected {
	_internal.connected = connected;
}

//- (id)description {};
- (BOOL)isConnected { return _internal.connected; };
- (unsigned int)connectionID { return _internal.connectionID; };
- (NSString *)manufacturer { return _internal.manufacturer; };
- (NSString *)name { return _internal.name; };
- (NSString *)modelNumber { return _internal.modelNumber; };
- (NSString *)serialNumber { return _internal.serialNumber; };
- (NSString *)firmwareRevision { return _internal.firmwareRevision; };
- (NSString *)hardwareRevision { return _internal.hardwareRevision; };
- (void)setDelegate:(id)arg1 {};
- (NSArray *)protocolStrings { return [_internal.protocols allValues]; };
- (id)delegate { return _internal.delegate; };
//- (id)_shortDescription {};
//- (id)_protocolIDForProtocolString:(id)arg1 {};

- (void)dealloc {
	[_internal release];
	[super dealloc];
};

@end
