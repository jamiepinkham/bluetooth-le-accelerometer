//
//  JPAppDelegate.m
//  AccelerometerBluetoothHost
//
//  Created by Jamie Pinkham on 12/19/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import "JPAppDelegate.h"

#import <IOBluetooth/IOBluetooth.h>

#import "JPServiceConstants.h"

@interface JPAppDelegate ()

@property (weak, nonatomic) IBOutlet NSTextField *xLabel;
@property (weak, nonatomic) IBOutlet NSTextField *yLabel;
@property (weak, nonatomic) IBOutlet NSTextField *zLabel;

@property (weak, nonatomic) IBOutlet NSProgressIndicator *xBar;
@property (weak, nonatomic) IBOutlet NSProgressIndicator *yBar;
@property (weak, nonatomic) IBOutlet NSProgressIndicator *zBar;

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *connectedPeripheral;

@property (nonatomic, strong) NSMutableArray *foundPeripherals;
@property (nonatomic, weak) IBOutlet NSArrayController *arrayController;

@property (nonatomic, weak) IBOutlet NSButton* connectButton;
@property (nonatomic, weak) IBOutlet NSButton * indicatorButton;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic, weak) IBOutlet NSWindow *scanSheet;

- (IBAction) openScanSheet:(id) sender;
- (IBAction) closeScanSheet:(id)sender;
- (IBAction) cancelScanSheet:(id)sender;
- (IBAction) connectButtonPressed:(id)sender;

@end


@implementation JPAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
	
	self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
	self.foundPeripherals = [NSMutableArray new];
}

- (void)dealloc
{
	[self stopScan];
	self.connectedPeripheral.delegate = nil;	
}

- (void)updateWithMotionData:(NSData *)data
{
	float motionXYZ[3];
	[data getBytes:&motionXYZ length:(3 * sizeof(float))];
//	NSLog(@"x = %f, y = %f, z = %f", motionXYZ[0], motionXYZ[1], motionXYZ[2]);
	
	[self.xLabel setStringValue:[NSString stringWithFormat:@"%f", motionXYZ[0]]];
	[self.xBar setDoubleValue:ABS(motionXYZ[0])];
	
	[self.yLabel setStringValue:[NSString stringWithFormat:@"%f", motionXYZ[1]]];
	[self.yBar setDoubleValue:ABS(motionXYZ[1])];
	
	[self.zLabel setStringValue:[NSString stringWithFormat:@"%f", motionXYZ[2]]];
	[self.zBar setDoubleValue:ABS(motionXYZ[2])];
	
	
}

- (void) stopScan
{
    [self.centralManager stopScan];
}

- (void) startScan
{
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:MOTION_SERVICE_UUID]] options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @NO}];
	NSLog(@"scanning started");
}

- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    [self isLECapableHardware];
}

- (BOOL) isLECapableHardware
{
    NSString * state = nil;
    
    switch ([self.centralManager state])
    {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStatePoweredOn:
            return TRUE;
        case CBCentralManagerStateUnknown:
        default:
            return FALSE;
            
    }
    
    NSLog(@"Central manager state: %@", state);
    
    [self cancelScanSheet:nil];
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:state];
    [alert addButtonWithTitle:@"OK"];
    [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
    return FALSE;
}

/*
 Invoked when the central discovers motion peripheral while scanning.
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
	
    
    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    NSMutableArray *peripherals = [self mutableArrayValueForKey:@"foundPeripherals"];
    if( ![self.foundPeripherals containsObject:peripheral] )
	{
        [peripherals addObject:peripheral];
	}
}


#pragma mark - Scan sheet methods

/*
 Open scan sheet to discover motion peripherals if it is LE capable hardware
 */
- (IBAction)openScanSheet:(id)sender
{
    if( [self isLECapableHardware] )
    {
        [self.arrayController removeObjects:self.foundPeripherals];
        [NSApp beginSheet:self.scanSheet modalForWindow:self.window modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
        [self startScan];
    }
}

/*
 Close scan sheet once device is selected
 */
- (IBAction)closeScanSheet:(id)sender
{
    [NSApp endSheet:self.scanSheet returnCode:NSAlertDefaultReturn];
    [self.scanSheet orderOut:self];
}

/*
 Close scan sheet without choosing any device
 */
- (IBAction)cancelScanSheet:(id)sender
{
    [NSApp endSheet:self.scanSheet returnCode:NSAlertAlternateReturn];
    [self.scanSheet orderOut:self];
}

/*
 This method is called when Scan sheet is closed. Initiate connection to selected motion peripheral
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [self stopScan];
    if( returnCode == NSAlertDefaultReturn )
    {
        NSIndexSet *indexes = [self.arrayController selectionIndexes];
        if ([indexes count] != 0)
        {
            NSUInteger anIndex = [indexes firstIndex];
            self.connectedPeripheral = [[self foundPeripherals] objectAtIndex:anIndex];
            [self.progressIndicator setHidden:FALSE];
            [self.progressIndicator startAnimation:self];
            [self.connectButton setTitle:@"Cancel"];
			[self.connectButton sizeToFit];
            [self.centralManager connectPeripheral:self.connectedPeripheral options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey : @YES}];
        }
    }
}

#pragma mark - Connect Button

/*
 This method is called when connect button pressed and it takes appropriate actions depending on device connection state
 */
- (IBAction)connectButtonPressed:(id)sender
{
    if(self.connectedPeripheral && ([self.connectedPeripheral isConnected]))
    {
        /* Disconnect if it's already connected */
        [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
    }
    else if (self.connectedPeripheral)
    {
        /* Device is not connected, cancel pendig connection */
        [self.progressIndicator setHidden:TRUE];
        [self.progressIndicator stopAnimation:self];
        [self.connectButton setTitle:@"Connect"];
		[self.connectButton sizeToFit];
        [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
        [self openScanSheet:nil];
    }
    else
    {   /* No outstanding connection, open scan sheet */
        [self openScanSheet:nil];
    }
}

- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)aPeripheral
{
    [aPeripheral setDelegate:self];
    [aPeripheral discoverServices:nil];
	
//	self.connected = @"Connected";
    [self.connectButton setTitle:@"Disconnect"];
	[self.connectButton sizeToFit];
    [self.progressIndicator setHidden:TRUE];
    [self.progressIndicator stopAnimation:self];
}

/*
 Invoked whenever an existing connection with the peripheral is torn down.
 Reset local variables
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
	
	NSLog(@"Did Disconnect to peripheral: %@ with error = %@", aPeripheral, [error localizedDescription]);
//	self.connected = @"Not connected";
    [self.connectButton setTitle:@"Connect"];
	[self.connectButton sizeToFit];
    if( self.connectedPeripheral )
    {
        [self.connectedPeripheral setDelegate:nil];
        self.connectedPeripheral = nil;
    }
	[self.xBar setDoubleValue:0.0];
	[self.yBar setDoubleValue:0.0];
	[self.zBar setDoubleValue:0.0];
	
	[self.xLabel setStringValue:@"0.0"];
	[self.yLabel setStringValue:@"0.0"];
	[self.zLabel setStringValue:@"0.0"];
	
}

/*
 Invoked whenever the central manager fails to create a connection with the peripheral.
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
    NSLog(@"Fail to connect to peripheral: %@ with error = %@", aPeripheral, [error localizedDescription]);
    [self.connectButton setTitle:@"Connect"];
	[self.connectButton sizeToFit];
    if( self.connectedPeripheral)
    {
        [self.connectedPeripheral setDelegate:nil];
        self.connectedPeripheral = nil;
    }
}

#pragma mark - CBPeripheral delegate methods
/*
 Invoked upon completion of a -[discoverServices:] request.
 Discover available characteristics on interested services
 */
- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverServices:(NSError *)error
{
    for (CBService *aService in aPeripheral.services)
    {
        NSLog(@"Service found with UUID: %@", aService.UUID);
        
        /* Motion Service */
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:MOTION_SERVICE_UUID]])
        {
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }
        
        /* GAP (Generic Access Profile) for Device Name */
        if ( [aService.UUID isEqual:[CBUUID UUIDWithString:CBUUIDGenericAccessProfileString]] )
        {
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }
    }
}

/*
 Invoked upon completion of a -[discoverCharacteristics:forService:] request.
 Perform appropriate operations on interested characteristics
 */
- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if ([service.UUID isEqual:[CBUUID UUIDWithString:MOTION_SERVICE_UUID]])
    {
        for (CBCharacteristic *aChar in service.characteristics)
        {
            /* Set notification on attitude measurement */
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:ATTITUDE_CHARACTERISTIC_UUID]])
            {
                [self.connectedPeripheral setNotifyValue:YES forCharacteristic:aChar];
                NSLog(@"Found a attitude Measurement Characteristic");
            }
        }
    }
    
    if ( [service.UUID isEqual:[CBUUID UUIDWithString:CBUUIDGenericAccessProfileString]] )
    {
        for (CBCharacteristic *aChar in service.characteristics)
        {
            /* Read device name */
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:CBUUIDDeviceNameString]])
            {
                [aPeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found a Device Name Characteristic");
            }
        }
    }
    
}

/*
 Invoked upon completion of a -[readValueForCharacteristic:] request or on the reception of a notification/indication.
 */
- (void) peripheral:(CBPeripheral *)aPeripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    /* Updated value for attitude measurement received */
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:ATTITUDE_CHARACTERISTIC_UUID]])
    {
        if( (characteristic.value)  || !error )
        {
            /* Update UI with motion data */
            [self updateWithMotionData:characteristic.value];
        }
    }
    /* Value for body sensor location received */
    
    /* Value for device Name received */
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CBUUIDDeviceNameString]])
    {
        NSString * deviceName = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        NSLog(@"Device Name = %@", deviceName);
    }
}


@end
