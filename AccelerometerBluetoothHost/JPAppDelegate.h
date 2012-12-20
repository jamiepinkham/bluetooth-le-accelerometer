//
//  JPAppDelegate.h
//  AccelerometerBluetoothHost
//
//  Created by Jamie Pinkham on 12/19/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOBluetooth/IOBluetooth.h>

@interface JPAppDelegate : NSObject <NSApplicationDelegate, CBCentralManagerDelegate, CBPeripheralDelegate>

@property (assign) IBOutlet NSWindow *window;

@end
