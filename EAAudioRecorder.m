//
//  EAAudioRecorder.m
//  ExternalAccessory
//
//  Created by Alex Winston on 8/16/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "EAAudioRecorder.h"


// EAAudioPlayer Singleton
static EAAudioRecorder *sharedAudioRecorder = nil;

@implementation EAAudioRecorder

+ (EAAudioRecorder *)sharedAudioRecorder {
    @synchronized(self) {
        if (sharedAudioRecorder == nil) {
            [[self alloc] init]; // Assignment not done here
        }
    }
    return sharedAudioRecorder;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (sharedAudioRecorder == nil) {
            sharedAudioRecorder = [super allocWithZone:zone];
            return sharedAudioRecorder;  // Assign and return on first allocation
        }
    }
    return nil; // Subsequent allocation attempts return nil
}

- (id)delegate {
	return delegate;
}

- (void)setDelegate:(id)aDelegate {
	delegate = aDelegate;
}

static void AQBufferCallback(void *audioQueueData,
							 AudioQueueRef audioQueueRef,
							 AudioQueueBufferRef audioQueueBufferRef,
							 const AudioTimeStamp *audioTimeStamp,
							 UInt32 numberPackets,
							 const AudioStreamPacketDescription *audioPacketDesc) {
	
	EAAudioRecorder *audioRecorder = (EAAudioRecorder *)audioQueueData;
	
	if (numberPackets > 0) {
		short *audioQueueBuffer = (short *)audioQueueBufferRef->mAudioData;
		
		for(int i = 0; i < numberPackets; i++) {
			if (audioRecorder->buffering && 
				(audioRecorder->bufferLength == kDataQueueBufferSize ||
				 audioRecorder->bufferIdleCount++ == kDataQueueBufferMaxIdleCount)) {
				
				// Write buffered data to the delegate
				// ???: unsigned char bufferCopy[audioRecorder->bufferLength];
				// memcpy(bufferCopy, audioRecorder->buffer, audioRecorder->bufferLength);
				//if ([audioRecorder->delegate respondsToSelector:@selector(write:maxLength:)])
				[audioRecorder->delegate write:(const unsigned char *)audioRecorder->buffer //bufferCopy
				 maxLength:audioRecorder->bufferLength];
				
				//printf("NOTIFY\n");
				audioRecorder->buffering = false;
				audioRecorder->bufferLength = 0;
			}
			
			// Synchronize 100 samples before receiving
			if (i > 100) audioRecorder->synchronized = YES;
			
			if (audioRecorder->synchronized) {
				float sample = (float)audioQueueBuffer[i]/(32767.0f);
				if (audioRecorder->started) {
					if (!audioRecorder->sampleBit)
						sample -= (audioRecorder->sampleAdjust += 0.0075);
					else
						sample -= (audioRecorder->sampleAdjust2 -= 0.01);
				}
				float cubed = (sample + 1.0) * (sample + 1.0) * (sample + 1.0) * (sample + 1.0);
				
				cubed = cubed > 1.0 ? 1.0 : cubed;
				cubed = cubed < 0.0 ? 0.0 : cubed;
				
				//float difference = audioRecorder->differences[0] + audioRecorder->differences[1] + audioRecorder->differences[2] + audioRecorder->differences[3];
				if (cubed >= 0.5) audioRecorder->sampleBit = 1;
				if (cubed < 0.5) audioRecorder->sampleBit = 0;
				
				// Get the current data sample from the audio queue buffer sample
				int startBit = cubed < 0.1 ? 1 : 0;
				if (!audioRecorder->started && startBit) {
					audioRecorder->started = true;
					audioRecorder->sampleAdjust = 0.0;
					audioRecorder->sampleAdjust2 = 0.0;
					audioRecorder->sampleCount = 4;
				}
				
				if (audioRecorder->started) {
					//printf("%f\n", cubed);
					
					// Decrement sampleCount while iterating the audio buffer
					audioRecorder->sampleCount--;
					if (!audioRecorder->sampleCount) {
						/*if (!audioRecorder->bitCount)
							printf("-2.0\n");
						else
							printf("-1.5\n");*/
						
						if (!audioRecorder->bitCount) {
							if ((float)audioQueueBuffer[i]/(32767.0f) > 0.1) {
								audioRecorder->bitCount = 9;
								audioRecorder->sampleBit = 0;
							}
						}
						
						audioRecorder->sampleCount = 5;
						
						// If the bit count reaches 9 then buffer the byte of data
						if (audioRecorder->bitCount == 9) {
							if (audioRecorder->sampleBit) {
								audioRecorder->buffering = true;
								audioRecorder->buffer[audioRecorder->bufferLength++] = audioRecorder->byte;
								audioRecorder->bufferIdleCount = 0;
								//printf("%02x ", audioRecorder->byte);
							}
							
							audioRecorder->started = false;
							audioRecorder->sampleBit = 0;
							audioRecorder->bitCount = 0;
							audioRecorder->byte = 0;
						} else {
							audioRecorder->bitCount++;
							audioRecorder->byte |= audioRecorder->sampleBit;//data;
							audioRecorder->byte = (audioRecorder->byte >> 1) | (audioRecorder->byte << 7);
						}
					}
				}
			}
		}
	}
	
	AudioQueueEnqueueBuffer(audioQueueRef, audioQueueBufferRef, 0, NULL);
}

- (id)init {
	if( !(self=[super init]) )
		return nil;
	
	// AudioStreamBasicDescription audio format
	audioFormat.mSampleRate = kAudioFormatSampleRate;
	audioFormat.mFormatID = kAudioFormatLinearPCM;
	audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	audioFormat.mBytesPerPacket = 2;
	audioFormat.mFramesPerPacket = 1;
    audioFormat.mBytesPerFrame = 2;
	audioFormat.mChannelsPerFrame = 1;
	audioFormat.mBitsPerChannel = 16;
	audioFormat.mReserved = 0;
	
	UInt32 err;
	err = AudioQueueNewInput(&audioFormat, AQBufferCallback, self, CFRunLoopGetMain(), kCFRunLoopCommonModes, 0, &audioQueue);
    if (err) [NSException raise:@"AudioInputError" format:@"AudioQueueNewInput failed: %d", err];
	err = AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 0.0);
    if (err) [NSException raise:@"AudioInputError" format:@"AudioQueueSetParameter failed: %d", err];
	
    return self;
}

- (void)start {
	UInt32 bufferBytes = audioFormat.mBytesPerFrame * kAudioQueueBufferSize;
	for (int i = 0; i < kAudioQueueBufferRefSize; i++) {
		UInt32 err = AudioQueueAllocateBuffer(audioQueue, bufferBytes, &audioQueueBuffers[i]);
        if (err) [NSException raise:@"AudioInputError" format:@"AudioQueueAllocateBuffer failed: %d", err];
		
		AudioQueueEnqueueBuffer(audioQueue, audioQueueBuffers[i], 0, NULL);
	}
	UInt32 err = AudioQueueStart(audioQueue, NULL);
    if (err) [NSException raise:@"AudioInputError" format:@"AudioQueueStart failed: %d", err];
}

- (void)stop {
	UInt32 err = AudioQueueStop(audioQueue, true);
    if (err) [NSException raise:@"AudioInputError" format:@"AudioQueueStop failed: %d", err];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
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
    if (err) [NSException raise:@"AudioInputError" format:@"AudioQueueDispose failed: %d", err];
	
	[super dealloc];
}

@end
