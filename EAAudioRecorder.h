//
//  EAAudioRecorder.h
//  ExternalAccessory
//
//  Created by Alex Winston on 8/16/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>


#define kAudioFormatSampleRate 96000
#define kAudioQueueBufferSize 512
#define kAudioQueueBufferRefSize 2
#define kDataQueueBufferSize 128
#define kDataQueueBufferMaxIdleCount 1024

@interface EAAudioRecorder : NSObject {
	AudioQueueRef				audioQueue;
    AudioQueueBufferRef			audioQueueBuffers[kAudioQueueBufferRefSize];
    AudioStreamBasicDescription audioFormat;
	
	id delegate;
	
	BOOL			buffering;
	unsigned char	buffer[kDataQueueBufferSize];
	int				bufferLength;
	int				bufferIdleCount;
	
	BOOL			synchronized;
	BOOL			started;
	int				bitCount;
	float			sample;
	float			sampleAdjust;
	float			sampleAdjust2;
	int				sampleCount;
	BOOL			sampleBit;
	unsigned char	byte;
	
	float			samples[4];
	float			differences[4];
}
+ (EAAudioRecorder *)sharedAudioRecorder;
- (id)delegate;
- (void)setDelegate:(id)aDelegate;
- (void)start;
- (void)stop;
@end
