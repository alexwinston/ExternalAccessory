//
//  EAOutputStream.m
//  ExternalAccessory
//
//  Created by Alex Winston on 8/16/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "EAOutputStream.h"
#import "EAAccessory.h"
#import "EASession.h"
#import "EAAudioPlayer.h"


@interface EAOutputStream (Private)
EAAudioPlayer *_audioPlayer;
@end

@implementation EAOutputStream

- (id)initWithAccessory:(id)accessory forSession:(id)session {
	if( !(self=[super init]) )
		return nil;
	
	_accessory = [accessory retain];
	_session = [session retain];
	_streamStatus = NSStreamStatusNotOpen;	
	
	// ???: Retain reference to EAAudioPlayer so synchronized calls to sharedAudioPlayer aren't made during write
	_audioPlayer = [[EAAudioPlayer sharedAudioPlayer] retain];
		
	return self;
}

- (void)setDelegate:(id)delegate {
	// ???: Research NSStreamEventEndEncountered
	//	[delegate stream:self handleEvent:NSStreamEventEndEncountered];
	
	_delegate = delegate;
	
	if ([_delegate respondsToSelector:@selector(stream:handleEvent:)])
		_delegateRespondsToStreamHandleEvent = YES;
}

- (BOOL)hasSpaceAvailable {
	return _hasSpaceAvailable;
}

- (unsigned int)streamStatus {
	return _streamStatus;
}

- (void)open {
	if (_streamStatus == NSStreamStatusOpen)
		return;
	_streamStatus = NSStreamStatusOpening;
	
	// TODO: Send data passthrough command
	//[_audioPlayer start];
	
	_streamStatus = NSStreamStatusOpen;
	if (_delegateRespondsToStreamHandleEvent)
		[_delegate stream:(void *)self handleEvent:NSStreamEventOpenCompleted];
}

- (void)close {
	//[_audioPlayer stop];
	_streamStatus = NSStreamStatusClosed;
}

// TODO: Do not enqueueData if the player isn't started
- (int)write:(const char *)chars maxLength:(unsigned int)length {
	if (_streamStatus != NSStreamStatusOpen)
		return 0;
	_streamStatus = NSStreamStatusWriting;
	
	// TODO: Test the enqueueData buffer size to determine hasSpaceAvailable
	for (int i = 0; i < 10; i++)
		[_audioPlayer enqueueData:1.0f]; // Mark
	
	// NOTE: Asynchronous serial communication http://en.wikipedia.org/wiki/Stop_bit
	for (int i = 0; i < length; i++) {
		for (int j = 0; j < 5; j++)
			[_audioPlayer enqueueData:-1.0f]; // Start bit
		
		// Most serial communications designs send the data bits within each byte LSB (Least Significant Bit) first.
		// This standard is also referred to as "little endian".
		for (int j = 0; j <= CHAR_BIT - 1; j++) {
			for (int k = 0; k < 5; k++)
				[_audioPlayer enqueueData:chars[i] & (1 << j) ? 1.0f : -1.0f]; // 8 data bits
		}
		
		for (int j = 0; j < 5; j++)
			[_audioPlayer enqueueData:1.0f]; // Stop bit
	}
	
	_streamStatus = NSStreamStatusOpen;
	
	// TODO: Check the number of bits enqueued
	return length;
}

- (void)dealloc {
	[_accessory release];
	[_session release];
	[_audioPlayer release];

	[super dealloc];
}

@end
