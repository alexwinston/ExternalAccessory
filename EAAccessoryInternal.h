//
//  EAAccessoryInternal.h
//  ExternalAccessory
//
//  Created by Alex Winston on 8/13/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//


@protocol EAAccessoryDelegate;

@interface EAAccessoryInternal : NSObject
{
    BOOL _connected;
    unsigned int _connectionID;
    NSString *_name;
    NSString *_manufacturer;
    NSString *_modelNumber;
    NSString *_serialNumber;
    NSString *_firmwareRevision;
    NSString *_hardwareRevision;
    NSDictionary *_protocols;
    id <EAAccessoryDelegate> _delegate;
}

@property BOOL connected;
@property unsigned int connectionID;
@property(copy) NSString *manufacturer;
@property(copy) NSString *name;
@property(copy) NSString *modelNumber;
@property(copy) NSString *serialNumber;
@property(copy) NSString *firmwareRevision;
@property(copy) NSString *hardwareRevision;

// Dictionary of strings representing the protocols with an active EASession 
@property(retain, readwrite) NSDictionary *protocols;

@property(retain) id <EAAccessoryDelegate> delegate;

@end
