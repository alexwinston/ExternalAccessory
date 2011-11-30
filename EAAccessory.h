//
//  EAAccessory.h
//  ExternalAccessory
//
//  NOTE: Data to the external accessory is automatically wrapped into an iAP
//        packet after bring sent to the output stream. The iAP wrapper is
//        automatically stripped from incoming packets before being sent to
//        the EAAccessory input stream.
//
//        Further information related to these wrapper can be found in the
//        iAP specifications.
//
//  Copyright 2008 Apple, Inc. All rights reserved.
//


@class EAAccessoryInternal;
@protocol EAAccessoryDelegate;

enum {
    EAConnectionIDNone = 0,
};

@interface EAAccessory : NSObject {
@private
    EAAccessoryInternal *_internal;
}

@property(readonly, getter=isConnected) BOOL connected;
@property(readonly) NSUInteger connectionID;
@property(readonly) NSString *manufacturer;
@property(readonly) NSString *name;
@property(readonly) NSString *modelNumber;
@property(readonly) NSString *serialNumber;
@property(readonly) NSString *firmwareRevision;
@property(readonly) NSString *hardwareRevision;
// Array of strings representing the protocols supported by the accessory
@property(readonly) NSArray *protocolStrings;
@property(retain) id<EAAccessoryDelegate> delegate;

- (id)_initWithAccessory:(EAAccessoryInternal *)accessory;
- (void)_setConnected:(BOOL)connected;

@end

@protocol EAAccessoryDelegate <NSObject>
@optional
- (void)accessoryDidDisconnect:(id)accessory;
@end