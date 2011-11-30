//
//  EAInputStream.h
//  ExternalAccessory
//
//  Created by Alex Winston on 8/18/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

@class EAAccessory;
@class EASession;

@interface EAInputStream : NSObject {
	id _delegate;
	BOOL _delegateRespondsToStreamHandleEvent;
	
    EAAccessory *_accessory;
    EASession *_session;
    char *_readBuffer;
	unsigned int _readBufferLength;
    NSMutableData *_inData;
    NSLock *_inDataLock;
    BOOL _isOpenCompletedEventSent;
    BOOL _hasNewBytesAvailable;
    BOOL _isAtEndEventSent;
    unsigned int _streamStatus;
	
	/* ???:TODO:
    CFRunLoopRef _runLoop; //struct __CFRunLoop *_runLoop;
    CFRunLoopSourceRef _runLoopSource; //struct __CFRunLoopSource *_runLoopSource;
    struct __CFFileDescriptor *_readCFFileDescriptor;
    CFRunLoopSourceRef _readRunLoopSource; //struct __CFRunLoopSource *_readRunLoopSource;
	 */
}
- (id)initWithAccessory:(id)arg1 forSession:(id)arg2;
- (void)dealloc;
/* TODO: Override
- (id)propertyForKey:(id)arg1;
- (BOOL)setProperty:(id)arg1 forKey:(id)arg2;
- (void)scheduleInRunLoop:(id)arg1 forMode:(id)arg2;
- (void)removeFromRunLoop:(id)arg1 forMode:(id)arg2;
- (id)streamError;
 */
// TODO: Implement
- (id)delegate;
- (void)setDelegate:(id)delegate;
- (unsigned int)streamStatus;
- (void)open;
- (void)close;
- (int)read:(char *)arg1 maxLength:(unsigned int)arg2;
- (BOOL)getBuffer:(char **)arg1 length:(unsigned int *)arg2;
- (BOOL)hasBytesAvailable;
- (void)_accessoryDidDisconnect:(id)arg1;
- (void)_performAtEndOfStreamValidation;
- (void)_streamEventTrigger;
- (void)_scheduleCallback;
- (void)_readData;
@end
