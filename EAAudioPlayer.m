//
//  EAAudioPlayer.m
//  ExternalAccessory
//
//  Created by Alex Winston on 8/16/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "EAAudioPlayer.h"


// EAAudioPlayer Singleton
static EAAudioPlayer *sharedAudioPlayer = nil;

@implementation EAAudioPlayer

+ (EAAudioPlayer *)sharedAudioPlayer {
    @synchronized(self) {
        if (sharedAudioPlayer == nil) {
            [[self alloc] init]; // Assignment not done here
        }
    }
    return sharedAudioPlayer;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (sharedAudioPlayer == nil) {
            sharedAudioPlayer = [super allocWithZone:zone];
            return sharedAudioPlayer;  // Assign and return on first allocation
        }
    }
    return nil; // Subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

static void AQBufferCallback(void *audioQueueData,
							 AudioQueueRef audioQueueRef,
							 AudioQueueBufferRef audioQueueBufferRef) {
	
	EAAudioPlayer *audioPlayer = (EAAudioPlayer *)audioQueueData;
	
	short *audioQueueBuffer = (short *)audioQueueBufferRef->mAudioData;
	audioQueueBufferRef->mAudioDataByteSize = sizeof(short) * kAudioQueueBufferBytes;

	for(int i = 0; i < kAudioQueueBufferBytes; i++) {
		//float data = sinf((float)i * M_PI / 180.0f); 
		float data = [audioPlayer dequeueData];
		data *= 32767.0f;
		
		audioQueueBuffer[i] = (short)data;
	}

	AudioQueueEnqueueBuffer(audioQueueRef, audioQueueBufferRef, 0, NULL);
}

- (id)init {
	if( !(self=[super init]) )
		return nil;
	
	// NSMutableArray that holds float data to be buffered for playback
	audioData = [[NSMutableArray arrayWithCapacity:512] retain];
	
	// AudioStreamBasicDescription audio format
	audioFormat.mSampleRate = kAudioQueueSampleRate;
	audioFormat.mFormatID = kAudioFormatLinearPCM;
	audioFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger; //| kAudioFormatFlagIsPacked;
	audioFormat.mBytesPerPacket = 2;
	audioFormat.mFramesPerPacket = 1;
    audioFormat.mBytesPerFrame = 2;
	audioFormat.mChannelsPerFrame = 1;
	audioFormat.mBitsPerChannel = 16;
	
	UInt32 err;
    err = AudioQueueNewOutput(&audioFormat, AQBufferCallback, self, CFRunLoopGetMain(), kCFRunLoopCommonModes, 0, &audioQueue);
	if (err) [NSException raise:@"AudioOutputError" format:@"AudioQueueNewOutput failed: %d", err];
	err = AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 1.0);
    if (err) [NSException raise:@"AudioOutputError" format:@"AudioQueueSetParameter failed: %d", err];
	UInt32 bufferBytes = audioFormat.mBytesPerFrame * kAudioQueueBufferBytes;
	for (int i = 0; i < kAudioQueueBufferRefCount; i++) {
		UInt32 err = AudioQueueAllocateBuffer(audioQueue, bufferBytes, &audioQueueBuffers[i]);
        if (err) [NSException raise:@"AudioOutputError" format:@"AudioQueueAllocateBuffer failed: %d", err];
	}

	return self;
}

- (void)start {
	for (int i = 0; i < kAudioQueueBufferRefCount; i++) {
		AQBufferCallback(self, audioQueue, audioQueueBuffers[i]);
	}
	UInt32 err = AudioQueueStart(audioQueue, NULL);
    if (err) [NSException raise:@"AudioOutputError" format:@"AudioQueueStart failed: %d", err];
}

- (void)stop {
	UInt32 err = AudioQueueStop(audioQueue, true);
    if (err) [NSException raise:@"AudioOutputError" format:@"AudioQueueStop failed: %d", err];
}

- (float)dequeueData {
	float data = 0.0f;
	if ([audioData count] == 0)
		return data;
	
	id dataObject = [audioData objectAtIndex:0];
    if (dataObject != nil) {
		data = [dataObject floatValue];
		//printf("%f\n", data);
        [audioData removeObjectAtIndex:0];
    }
	
    return data;
}

- (void)enqueueData:(float)data {
	// ???: NSLock
	// TODO: Do not enqueueData if the player isn't started
	[audioData addObject:[NSNumber numberWithFloat:data]];
}

- (id)retain {
    return self;
}

- (unsigned)retainCount {
    return UINT_MAX;  // Denotes an object that cannot be released
}

- (void)release {
}

- (id)autorelease {
    return self;
}

- (void)dealloc {
	UInt32 err = AudioQueueDispose(audioQueue, true);
    if (err) [NSException raise:@"AudioOutputError" format:@"AudioQueueDispose failed: %d", err];
	
	[audioData release];
	[super dealloc];
}

@end
