//
//  EAOutputStream.h
//  ExternalAccessory
//
//  Created by Alex Winston on 8/16/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//


@class EAAccessory;
@class EASession;

@interface EAOutputStream : NSOutputStream
{
    id _delegate;
	BOOL _delegateRespondsToStreamHandleEvent;
	
    int _outfd;
    EAAccessory *_accessory;
    EASession *_session;
    BOOL _isOpenCompletedEventSent;
    BOOL _hasSpaceAvailableEventSent;
    BOOL _hasSpaceAvailable;
    BOOL _isAtEndEventSent;
    unsigned int _streamStatus;
    struct __CFRunLoop *_runLoop;
    struct __CFRunLoopSource *_runLoopSource;
    NSThread *_writeAvailableThread;
    BOOL _isWriteAvailableThreadCancelled;
    NSCondition *_writeAvailableThreadRunCondition;
}

- (id)initWithAccessory:(id)accessory forSession:(id)session;
- (void)setDelegate:(id)delegate;
- (BOOL)hasSpaceAvailable;
- (int)write:(const char *)chars maxLength:(unsigned int)length;

@end
