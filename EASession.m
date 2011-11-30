//
//  EASession.m
//  ExternalAccessory
//
//  Created by Alex Winston on 8/13/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "EASession.h"
#import "EAAccessory.h"
#import "EAInputStream.h"
#import "EAOutputStream.h"


@implementation EASession

- (id)initWithAccessory:(EAAccessory *)accessory forProtocol:(NSString *)protocolString {
	if( !(self=[super init]) )
		return nil;
	
	_accessory = [accessory retain];
	_protocolString = [protocolString retain];
	
	_inputStream = [[[EAInputStream alloc] initWithAccessory:nil forSession:nil] retain];
	_outputStream = [[[EAOutputStream alloc] initWithAccessory:nil forSession:nil] retain];
	
	return self;
};
- (void)dealloc {
	[_accessory release];
	[_protocolString release];
	[_inputStream release];
	[_outputStream release];
	[super dealloc];
};
- (id)description {};
- (id)_shortDescription {};
- (unsigned int)_sessionID {};
- (id)outputStream {
	return _outputStream;
};
- (id)inputStream {
	return _inputStream;
};
- (id)protocolString {
	return _protocolString;
};
- (id)accessory {
	return _accessory;
};

@end
