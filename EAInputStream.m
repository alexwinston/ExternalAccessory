//
//  EAInputStream.m
//  ExternalAccessory
//
//  Created by Alex Winston on 8/18/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "EAInputStream.h"
#import "EAAccessory.h"
#import "EASession.h"
#import "EAAudioRecorder.h"


@interface EAInputStream (Private)
EAAudioRecorder *_audioRecorder;
@end

@implementation EAInputStream

- (id)initWithAccessory:(id)accessory forSession:(id)session {
	if( !(self=[super init]) )
		return nil;
	
	_accessory = [accessory retain];
	_session = [session retain];
	_streamStatus = NSStreamStatusNotOpen;
	
	_inData = [[NSMutableData dataWithCapacity:kDataQueueBufferSize] retain];
	_inDataLock = [NSLock new];
	_readBuffer = malloc(kDataQueueBufferSize);
	
	// Set self as the EAAudioRecorder delegate to receive write:maxLength: callbacks
	_audioRecorder = [[EAAudioRecorder sharedAudioRecorder] retain];
	
	return self;
}

- (id)delegate {
	return _delegate;
}

- (void)setDelegate:(id)delegate {
	// ???: Research NSStreamEventEndEncountered
	//	[delegate stream:self handleEvent:NSStreamEventEndEncountered];
	
	_delegate = delegate;
	
	if ([_delegate respondsToSelector:@selector(stream:handleEvent:)])
		_delegateRespondsToStreamHandleEvent = YES;
}

- (BOOL)hasBytesAvailable {
	return [_inData length] > 0;
}

- (unsigned int)streamStatus {
	return _streamStatus;
}

- (void)open {
	if (_streamStatus == NSStreamStatusOpen)
		return;
	_streamStatus = NSStreamStatusOpening;
	
	[_audioRecorder setDelegate:self];
	//[_audioRecorder start];
	
	_streamStatus = NSStreamStatusOpen;
	if (_delegateRespondsToStreamHandleEvent)
		[_delegate stream:(void *)self handleEvent:NSStreamEventOpenCompleted];
}

- (void)close {
	[_audioRecorder setDelegate:nil];
	//[_audioRecorder stop];
	_streamStatus = NSStreamStatusClosed;
}

// Delegate method called by EAAudioRecorder after data bytes are buffered
- (int)write:(const char *)chars maxLength:(unsigned int)length {
	// ???:Research NSStreamStatusOpen and NSStreamStatusAtEnd
	_streamStatus = NSStreamStatusOpen;
	
	// ???: Research whether NSLock should be used here
	[_inDataLock lock];
	_readBufferLength = length;
	memcpy(_readBuffer, chars, _readBufferLength);
	[_inData appendBytes:_readBuffer length:_readBufferLength];
	[_inDataLock unlock];
	
	// TODO: NSStreamEventErrorOccurred
	
	if (_delegateRespondsToStreamHandleEvent)
		[_delegate stream:(void *)self handleEvent:NSStreamEventHasBytesAvailable];

	return _readBufferLength;
}

- (int)read:(char *)buffer maxLength:(unsigned int)maxLength {
	if (_streamStatus != NSStreamStatusOpen)
		return 0;
	
	_streamStatus = NSStreamStatusReading;
	
	// ???: Research whether NSLock should be used here
	[_inDataLock lock];
	int bytesRead = [_inData length];
	if (maxLength < bytesRead)
		bytesRead = maxLength;
	[_inData getBytes:buffer length:bytesRead];
	
	int bytesRemainingLength = [_inData length] - bytesRead;
	uint8_t buf[bytesRemainingLength];
	[_inData getBytes:buf range:NSMakeRange(bytesRead, bytesRemainingLength)];
	[_inData replaceBytesInRange:NSMakeRange(0, bytesRemainingLength) withBytes:buf];
	[_inData setLength:bytesRemainingLength];
	//[_inData release];
	
	//_inData = [[NSMutableData dataWithBytes:buf length:bytesRemainingLength] retain];
	[_inDataLock unlock];
	
	_streamStatus = NSStreamStatusAtEnd;
	
	return bytesRead;
}

- (BOOL)getBuffer:(char **)buffer length:(unsigned int *)len {
	buffer = &_readBuffer;
	len = &_readBufferLength;
	
	return YES;
}

- (void)dealloc {
	[_accessory release];
	[_session release];
	[_inData release];
	[_inDataLock release];
	[_audioRecorder release];
	free(_readBuffer);

	[super dealloc];
}

@end
