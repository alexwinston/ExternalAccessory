//
//  EAAudioPlayer.h
//  ExternalAccessory
//
//  Created by Alex Winston on 8/16/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>


#define kAudioQueueSampleRate 96000
#define kAudioQueueBufferBytes 4096
#define kAudioQueueBufferRefCount 4

@interface EAAudioPlayer : NSObject {
	AudioQueueRef audioQueue;
    AudioQueueBufferRef audioQueueBuffers[kAudioQueueBufferRefCount];
    AudioStreamBasicDescription audioFormat;
	
	NSMutableArray *audioData;
}
+ (EAAudioPlayer *)sharedAudioPlayer;
- (void)start;
- (void)stop;
- (float)dequeueData;
- (void)enqueueData:(float)data;
@end
