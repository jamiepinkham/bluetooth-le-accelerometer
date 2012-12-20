//
//  JPViewController.m
//  AccelerometerBluetoothPeripheral
//
//  Created by Jamie Pinkham on 12/19/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import "JPViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreMotion/CoreMotion.h>

#import "JPServiceConstants.h"

@interface JPViewController () <CBPeripheralManagerDelegate>

@property (nonatomic, strong) CBPeripheralManager *peripheralManager;
@property (nonatomic, strong) CBMutableService *motionService;
@property (nonatomic, strong) CBMutableCharacteristic *attitudeCharacteristic;

@property (nonatomic, strong) NSMutableArray *centrals;

@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) CMAttitude *referenceAttitude;

@property (weak, nonatomic) IBOutlet UILabel *xLabel;
@property (weak, nonatomic) IBOutlet UILabel *yLabel;
@property (weak, nonatomic) IBOutlet UILabel *zLabel;

@property (weak, nonatomic) IBOutlet UIProgressView *xBar;
@property (weak, nonatomic) IBOutlet UIProgressView *yBar;
@property (weak, nonatomic) IBOutlet UIProgressView *zBar;

@property (weak, nonatomic) IBOutlet UIButton *motionUpdatesButton;
@property (assign, nonatomic, getter = isTrackingMotion) BOOL trackingMotion;

@end

@implementation JPViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
	self.centrals = [NSMutableArray array];
	
	self.motionManager = [[CMMotionManager alloc] init];
	self.motionManager.deviceMotionUpdateInterval = 0.1;

	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskPortrait;
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    // Opt out from any other state
    if (peripheral.state != CBPeripheralManagerStatePoweredOn)
	{
        return;
    }
    
    // We're in CBPeripheralManagerStatePoweredOn state...
    NSLog(@"self.peripheralManager powered on.");
    
    // ... so build our service.
    
    // Start with the CBMutableCharacteristic
    self.attitudeCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:ATTITUDE_CHARACTERISTIC_UUID]
																	 properties:CBCharacteristicPropertyNotify
																		  value:nil
																	permissions:CBAttributePermissionsReadable];
	
    // Then the service
	self.motionService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:MOTION_SERVICE_UUID]
																	   primary:YES];
    
    // Add the characteristic to the service
    self.motionService.characteristics = @[self.attitudeCharacteristic];
    
    // And add it to the peripheral manager
    [self.peripheralManager addService:self.motionService];
	
	[self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:MOTION_SERVICE_UUID]] }];


}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    [[self centrals] addObject:central];

}


/** Recognise when the central unsubscribes
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
	[[self centrals] removeObject:central];
	if([[self centrals] count] == 0)
	{
//		[self.motionManager stopAccelerometerUpdates];
	}
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    // Start sending again
    NSLog(@"peripheral manager is ready to update subscribers");
}

- (IBAction)startAction:(id)sender
{
	if(!self.trackingMotion)
	{
		[self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *motion, NSError *error) {
			CMAttitude *attitude = motion.attitude;
			if(self.referenceAttitude)
			{
				[attitude multiplyByInverseOfAttitude:self.referenceAttitude];
				self.xLabel.text = [NSString stringWithFormat:@"%f", attitude.pitch];
				self.xBar.progress = ABS(attitude.pitch);
				
				self.yLabel.text = [NSString stringWithFormat:@"%f", attitude.roll];
				self.yBar.progress = ABS(attitude.roll);
				
				self.zLabel.text = [NSString stringWithFormat:@"%f", attitude.yaw];
				self.zBar.progress = ABS(attitude.yaw);
				
				float rotationXYZ[3];
				rotationXYZ[0] = attitude.pitch;
				rotationXYZ[1] = attitude.roll;
				rotationXYZ[2] = attitude.yaw;
				
				NSMutableData *controlData = [NSMutableData new];
				[controlData appendBytes:&rotationXYZ length:(3 * sizeof(float))];
				
				
				if([[self centrals] count])
				{
					[[self peripheralManager] updateValue:controlData forCharacteristic:self.attitudeCharacteristic onSubscribedCentrals:[self centrals]];
					//				NSLog(@"sent = %@", success?@"YES":@"NO");
				}
				
			}
			else
			{
				self.referenceAttitude = attitude;
			}
		}];
	}
	else
	{
		self.referenceAttitude = nil;
		
		self.xLabel.text = @"0.0";
		self.yLabel.text = @"0.0";
		self.zLabel.text = @"0.0";
		
		[self.xBar setProgress:0.0];
		[self.yBar setProgress:0.0];
		[self.zBar setProgress:0.0];
		
		[self.motionManager stopDeviceMotionUpdates];
	}
	self.trackingMotion = !self.trackingMotion;
	[self.motionUpdatesButton setTitle:(self.trackingMotion  ? @"Stop" : @"Start") forState:UIControlStateNormal];
	[self.motionUpdatesButton sizeToFit];
}



@end
