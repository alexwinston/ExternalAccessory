//
//  EASession.h
//  ExternalAccessory
//
//  Copyright 2008 Apple Inc.. All rights reserved.
//


@class EAAccessory;

@interface EASession : NSObject {
@private
    EAAccessory *_accessory;
    NSUInteger _sessionID;
    NSString *_protocolString;
    NSInputStream *_inputStream;
    NSOutputStream *_outputStream;
}

- (id)initWithAccessory:(EAAccessory *)accessory forProtocol:(NSString *)protocolString;

@property (nonatomic, readonly) EAAccessory *accessory;
@property (nonatomic, readonly) NSString *protocolString;
@property (nonatomic, readonly) NSInputStream *inputStream;
@property (nonatomic, readonly) NSOutputStream *outputStream;
@end