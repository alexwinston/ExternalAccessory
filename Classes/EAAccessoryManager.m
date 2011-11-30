//
//  EAAccessoryManager.m
//  ExternalAccessory
//
//  Created by Alex Winston on 8/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <sys/utsname.h>
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>
#import "EAAccessoryManager.h"
#import "EAAccessory.h"
#import "EAAccessoryInternal.h"
#import "EAAudioPlayer.h"
#import "EAAudioRecorder.h"
#import "EAInputStream.h"
#import "EAOutputStream.h"

#define kValidAcknowledgementLength 5

// EAAccessoryManager Notifications
NSString *const EAAccessoryDidConnectNotification = @"EAAccessoryDidConnectNotification";
NSString *const EAAccessoryDidDisconnectNotification = @"EAAccessoryDidDisconnectNotification";
// Keys in the EAAccessoryDidArriveNotification/EAAccessoryDidDisconnectNotification userInfo
NSString *const EAAccessoryKey = @"EAAccessoryKey";

// EAAccessoryManager Singleton
static EAAccessoryManager *sharedAccessoryManager = nil;

void decrypt(int strLen, unsigned char *ePtr, int keyLen, char key[]) {
	for (int i=0, j=0;i<strLen;i++)
	{
		ePtr[i]=ePtr[i]^key[j++];
		if(j==keyLen) j=0;
	}
}

unsigned char CCITT8(int dataLength, unsigned char data[])
{
	unsigned char crc = 0;
	for (int i = 0; i < dataLength; i++)
	{
		crc = CRCTable[(crc ^ data[i]) & 0xFF];
	}
	return crc;
}

@interface EAAccessoryManager (Private)

BOOL registeredForLocalNotifications;
BOOL audioSessionInterrupted;
BOOL audioInputIsAvailable;
NSTimer *handshakeTimer;

- (void)audioInputAvailable:(UInt32)inputIsAvailable;
- (void)postNotificationWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo;
- (void)externalAccessoryConnected:(EAAccessoryInternal *)accessoryInternal;
- (void)externalAccessoryDisconnected:(EAAccessoryInternal *)accessoryInternal;
// TODO: Implement
- (void)notifyObserversThatAccessoryDisconnected:(id)arg1;
@end

@implementation EAAccessoryManager

+ (EAAccessoryManager*)sharedAccessoryManager {
    @synchronized(self) {
        if (sharedAccessoryManager == nil) {
            [[self alloc] init]; // Assignment not done here
        }
    }
    return sharedAccessoryManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (sharedAccessoryManager == nil) {
            sharedAccessoryManager = [super allocWithZone:zone];
            return sharedAccessoryManager;  // Assign and return on first allocation
        }
    }
    return nil; // Subsequent allocation attempts return nil
}

// TODO: Implement interruption listener callback when a call is received
void interruptionListenerCallback(void *inUserData, UInt32 interruptionState) {
	// you could do this with a cast below, but I will keep it here to make it clearer
	//YourSoundControlObject *controller = (YourSoundControlObject *) inUserData;
	
	if (interruptionState == kAudioSessionBeginInterruption) {
		NSLog(@"kAudioSessionBeginInterruption");
	} else if (interruptionState == kAudioSessionEndInterruption) {
		NSLog(@"kAudioSessionEndInterruption");
	}
}

void audioInputAvailableCallback(void *inUserData, AudioSessionPropertyID inID, UInt32 inDataSize, const void *inData)
{
	UInt32 audioInputIsAvailable = *(UInt32 *)inData;
    //NSLog(@"audioInputAvailableCallback %i", audioInputIsAvailable);
	
	EAAccessoryManager *accessoryManager = (EAAccessoryManager *)inUserData;
	[accessoryManager audioInputAvailable:audioInputIsAvailable];
}

void audioRouteChangeCallback(void *inUserData, AudioSessionPropertyID inID, UInt32 inDataSize, const void *inData)
{ 
	EAAccessoryManager *accessoryManager = (EAAccessoryManager *)inUserData;
	//NSLog(@"audioRouteChangeCallback:");
	
	CFDictionaryRef routeChangeDictionary = inData;
	CFNumberRef routeChangeReasonRef =
		CFDictionaryGetValue(routeChangeDictionary, CFSTR(kAudioSession_AudioRouteChangeKey_Reason));
	
	SInt32 routeChangeReason;
	CFNumberGetValue(routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason);
	
	CFStringRef oldRoute = (CFStringRef)CFDictionaryGetValue(routeChangeDictionary, CFSTR(kAudioSession_AudioRouteChangeKey_OldRoute));
	//NSLog(@"oldRoute %@", (NSString *)oldRoute);
	
	CFStringRef newRoute;
	UInt32 newRouteSize; newRouteSize = sizeof(newRoute);
	OSStatus err = AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &newRouteSize, &newRoute);
	if (err) [NSException raise:@"AudioSessionError" format:@"AudioSessionGetProperty failed: %d", err];
	//NSLog(@"newRoute %@", (NSString *)newRoute);
	
	if ([(NSString *)newRoute isEqualToString:@"HeadsetInOut"]) {
		[accessoryManager audioInputAvailable:YES];
	} else {
		if ([(NSString *)oldRoute isEqualToString:@"HeadsetInOut"])
			[accessoryManager audioInputAvailable:NO];
	}
}

- (id)init {
	if( !(self=[super init]) )
		return nil;
	
	_connectedAccessories = [[NSMutableArray array] retain];
	
	UInt32 err;
	err = AudioSessionInitialize(CFRunLoopGetMain(), kCFRunLoopDefaultMode, NULL, NULL);
	if (err) [NSException raise:@"AudioSessionError" format:@"AudioSessionInitialize failed: %d", err];
	
	if ([[[UIDevice currentDevice] model] isEqualToString:@"iPhone"]) {
		err = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, audioRouteChangeCallback, self);
		if (err) [NSException raise:@"AudioSessionError" format:@"AudioSessionAddPropertyListener failed: %d", err];
	} else {
		err = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioInputAvailable, audioInputAvailableCallback, self);
		if (err) [NSException raise:@"AudioSessionError" format:@"AudioSessionAddPropertyListener failed: %d", err];
	}
	
	UInt32 category = kAudioSessionCategory_PlayAndRecord;
	err = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
	if (err) [NSException raise:@"AudioSessionError" format:@"AudioSessionSetProperty failed: %d", err];	

	CFStringRef route;
	UInt32 routeSize; routeSize = sizeof(CFStringRef);
	err = AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &routeSize, &route);
	if (err) [NSException raise:@"AudioSessionError" format:@"AudioSessionGetProperty failed: %d", err];

	if ([(NSString *)route isEqualToString:@"HeadsetInOut"]) {
		// The accessory is connected, send acknowledgement request
		[self audioInputAvailable:YES];
	}
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (NSArray *)connectedAccessories {
	return _connectedAccessories;
}

- (void)registerForLocalNotifications {
	registeredForLocalNotifications = YES;
}

- (void)unregisterForLocalNotifications {
	registeredForLocalNotifications = NO;
}

// TODO: Reset volume to max when accessory is connected
- (void)volumeChanged:(NSNotification *)notification {
	//NSLog(@"volumeChanged:");
}

- (void)audioInputAvailable:(UInt32)inputIsAvailable {
	
	if (inputIsAvailable) {
		if (!audioInputIsAvailable) {
			//NSLog(@"audioInputAvailable:%i", inputIsAvailable);
			audioInputIsAvailable = YES;
			
			UInt32 err = AudioSessionSetActive(true);
			if (err) [NSException raise:@"AudioSessionError" format:@"AudioSessionSetActive failed: %d", err];
			
			[[EAAudioPlayer sharedAudioPlayer] start];
			[[EAAudioRecorder sharedAudioRecorder] start];
			
			// !!!: This probably creates a leak, should do more research
			EAInputStream *inputStream = [[EAInputStream alloc] initWithAccessory:nil forSession:nil];
			[inputStream setDelegate:self];
			[inputStream open];
			
			handshakeTimer = [[NSTimer scheduledTimerWithTimeInterval:2.0
											 target:self
										   selector:@selector(handshakeTimer:)
										   userInfo:inputStream
											repeats:YES] retain];
		}
	} else {
		if (audioInputIsAvailable) {
			//NSLog(@"audioInputAvailable %i", inputIsAvailable);
			audioInputIsAvailable = NO;
			
			// Invalidate the timer if an acknowledgement was never received
			if (handshakeTimer) {
				[handshakeTimer invalidate];
				[handshakeTimer release];
				handshakeTimer = nil;
			}
			
			// Stop the shared audio player and recorder
			[[EAAudioPlayer sharedAudioPlayer] stop];
			[[EAAudioRecorder sharedAudioRecorder] stop];
			
			UInt32 err = AudioSessionSetActive(false);
			if (err) [NSException raise:@"AudioSessionError" format:@"AudioSessionSetActive failed: %d", err];
			
			// Remove EAAccessory from the NSMutableArray of connected accessories
			if ([_connectedAccessories count] != 0) {
				EAAccessory *accessory = [_connectedAccessories objectAtIndex:0];
				[_connectedAccessories removeAllObjects];
				
				// Send EAAccessoryDidDisconnectNotification if registered for local notifications
				if (registeredForLocalNotifications)
					[self postNotificationWithName:EAAccessoryDidDisconnectNotification
											object:self
										  userInfo:[NSDictionary dictionaryWithObject:accessory
																			   forKey:EAAccessoryKey]];
			}
		}
	}	
}

- (void)handshakeTimer:(NSTimer *)timer
{
	//NSLog(@"handshakeTimer:");
    EAOutputStream *outputStream = [[EAOutputStream alloc] initWithAccessory:nil forSession:nil];
	[outputStream open];
	
	struct utsname u;
	uname(&u);
	NSString *machineName = [NSString stringWithFormat:@"%s", u.machine];
	NSLog(@"utsname.machine %@", machineName);
	if ([machineName isEqualToString:@"iPhone1,2"]) {
		// !!!: 3GS is not inverted
		char invert[] = { 0x02, 0x04, 0x10, 0xFF }; // iPhone 3GS 0x11
		[outputStream write:invert maxLength:4];
	} else {
		char uninvert[] = { 0x02, 0x04, 0x11, 0xFF };
		[outputStream write:uninvert maxLength:4];
	}
	
	
	char handshake[] = { 0x02, 0x04, 0x44, 0xFF };
	[outputStream write:handshake maxLength:4];
	[outputStream close];
} 

- (void)postNotificationWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo {
	NSNotification *notification = [NSNotification notificationWithName:name
																 object:object
															   userInfo:userInfo];
	[[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
	
    switch(eventCode) {
        case NSStreamEventHasBytesAvailable:
        {
			NSLog(@"stream:handleEvent: hasBytesAvailable:%d", [(NSInputStream *)stream hasBytesAvailable]);
			
			unsigned char chars[512];
            unsigned int length = [(NSInputStream *)stream read:chars maxLength:512];
            if(length > kValidAcknowledgementLength) {
				int packetLength = length - 1;
				unsigned char packet[packetLength];
				strncpy((char *)packet, (char *)chars, packetLength);
				
				int keyLength = 7;
				char key[] = "5214630";
				decrypt(packetLength, packet, keyLength, key);

				// Check stream CRC against the decrypted packet CRC
				unsigned char streamCrc = chars[packetLength];
				unsigned char decryptedCrc = CCITT8(packetLength, packet);
				if (streamCrc != decryptedCrc) {//[attributes count] != 7) {
					return;
				}
				
				// Invalidate the timer if an acknowledgement was never received
				if (handshakeTimer) {
					[handshakeTimer invalidate];
					[handshakeTimer release];
					handshakeTimer = nil;
				}
				
				EAAccessoryInternal *accessoryInternal = [[EAAccessoryInternal alloc] init];
				accessoryInternal.connected = YES;
				
				const unichar seperator = 0x1E;
				NSString *seperatorString = [NSString stringWithCharacters:&seperator length:1];
				// TODO: Check attributesString length is valid
				NSString *attributesString = [NSString stringWithCString:(char *)packet length:packetLength - 1];
				NSArray *attributes = [attributesString componentsSeparatedByString:seperatorString];
				
				// TODO: accessoryInternal.manufacturer = [attributes objectAtIndex:0];
				accessoryInternal.name = [attributes objectAtIndex:0];
				accessoryInternal.modelNumber = [attributes objectAtIndex:1];
				accessoryInternal.serialNumber = [attributes objectAtIndex:2];
				accessoryInternal.firmwareRevision = [attributes objectAtIndex:3];
				accessoryInternal.hardwareRevision = [attributes objectAtIndex:4];
				
				// TODO: Check protocols support and set key correctly
				NSMutableDictionary *protocols = [[NSMutableDictionary dictionary] autorelease];
				[protocols setValue:[attributes objectAtIndex:5] forKey:@"EAProtocolsKey"];
				accessoryInternal.protocols = protocols;
				
				// Use rolling key to enable passthrough, should consider acknowledgement
				char rollingChar = packet[packetLength - 1];
				char passthrough[] = { 0x02, 0x05, 0x04, rollingChar, 0xFF };
				EAOutputStream *outputStream = [[EAOutputStream alloc] initWithAccessory:nil forSession:nil];
				[outputStream open];
				[outputStream write:passthrough maxLength:5];
				[outputStream close];
				
				[self externalAccessoryConnected:accessoryInternal];
			}
		}
	}
}

- (void)externalAccessoryConnected:(EAAccessoryInternal *)accessoryInternal {
	// Add EAAccessory to the NSMutableArray of connected accessories
	EAAccessory *accessory = [[[EAAccessory alloc] _initWithAccessory:accessoryInternal] autorelease];
	//NSLog(@"Model Number: %@", accessory.modelNumber);
	
	// !!!: This implementation of the External Accessory framework only allows one connected accessory at a time
	[_connectedAccessories removeAllObjects];
	[_connectedAccessories addObject:accessory];
	
	// Send EAAccessoryDidConnectNotification if registered for local notifications
	if (registeredForLocalNotifications)
		[self postNotificationWithName:EAAccessoryDidConnectNotification
								object:self
							  userInfo:[NSDictionary dictionaryWithObject:accessory
																   forKey:EAAccessoryKey]];
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
	[_connectedAccessories release];
	
	// TODO: Remove property listeners
	if ([[[UIDevice currentDevice] model] isEqualToString:@"iPhone"]) {
		//UInt32 err = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, audioRouteChangeCallback, self);
		//if (err) [NSException raise:@"AudioSessionError" format:@"AudioSessionAddPropertyListener failed: %d", err];
	} else {
		//UInt32 err = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioInputAvailable, audioInputAvailableCallback, self);
		//if (err) [NSException raise:@"AudioSessionError" format:@"AudioSessionAddPropertyListener failed: %d", err];
	}
	
	[super dealloc];
}

@end
