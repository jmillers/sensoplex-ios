//
//  SPViewController.m
//  SensoPlex
//
//  Created by Jeremy Millers on 9/19/13.
//  Copyright (c) 2013 SweetSpotScience. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.

//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.

//  You should have received a copy of the GNU Lesser General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "SPViewController.h"
#import "SensoPlex.h"
#import "SensorData.h"
#import "SSPacketLogger.h"
#import "MoLogger.h"

#import <MessageUI/MessageUI.h>
#import <CoreBluetooth/CoreBluetooth.h>

// some constants
#define kDefaultStatusInterval 2
#define kWaitForSensorConnectInterval 5

// packet period to update the UI at to show streaming data
#define kUIPacketRefreshPeriod 1

// define to enable BLE Packet logging for debugging
#define kLogBLEPackets YES

@interface SPViewController () <SensoPlexDelegate, SensoPlexSensorDataDelegate, MFMailComposeViewControllerDelegate> {
    
    // flag to make sure that we delete old sensor data that
    // was serialized when starting new capture sessions
    BOOL deletedOldSerializedSensorData;
}

// sensor connection progress UI display
@property (weak, nonatomic) IBOutlet UIImageView *sensorConnectedImage;
@property (weak, nonatomic) IBOutlet UILabel *sensorConnectedLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *sensorConnectingProgressView;

// status labels
@property (weak, nonatomic) IBOutlet UILabel *sensorInstructionsLabel;
@property (weak, nonatomic) IBOutlet UILabel *bluetoothInstructionsLabel;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

// ui SensoPlex action buttons
@property (weak, nonatomic) IBOutlet UIButton *toggleLEDButton;
@property (weak, nonatomic) IBOutlet UIButton *startStreamingDataButton;
@property (weak, nonatomic) IBOutlet UIButton *stopStreamingDataButton;
@property (weak, nonatomic) IBOutlet UIButton *getFirmwareVersionButton;
@property (weak, nonatomic) IBOutlet UIButton *getStatusButton;

// email data ui elements
@property (weak, nonatomic) IBOutlet UIToolbar *bottomToolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *emailStreamedDataButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *leftSpaceButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *rightSpaceButton;

// show status to the user
- (void) promptUserToTurnOnSensor;
- (void) promptUserToTurnBluetoothOn;

// SensoPlex actions
-(IBAction) toggleLED:(id)sender;
-(IBAction) startStreamingData:(id)sender;
-(IBAction) stopStreamingData:(id)sender;
-(IBAction) emailStreamedData:(id)sender;
-(IBAction) getFirmwareVersion:(id)sender;
-(IBAction) getStatus:(id)sender;

// update the UI to show certain states
-(void) showDataIsStreaming;
-(void) showDataIsNotStreaming;

// show or hide the button to email sensor data
- (void) showEmailStreamedDataButton;
- (void) hideEmailStreamedDataButton;

@end


@implementation SPViewController

- (void) dealloc {
    [self cleanupSensoPlex];
    self.sensoPlex = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
	// clear our bottom toolbar to start out
    self.bottomToolbar.items = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.isDisplaying = YES;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    
    // initialize our SensoPlex object that we use to interact with the sensor (if we need to)
    [self initializeSensoPlex];
        
    // if we are not connected, then scan for our peripheral to connect to
    SensoPlexState state = self.sensoPlex.state;
    if ( state == SensoPlexDisconnected || state == SensoPlexFailedToConnect ) {
        [self.sensoPlex scanForBLEPeripherals];
    } else {
        [self showConnectionState:state];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    // don't keep scanning if we're not showing
    [self.sensoPlex stopScanningForBLEPeripherals];
    
    // make sure we stop capturing data as well
    [self.sensoPlex stopCapturingData];
    
    self.isDisplaying = NO;
    
    [super viewWillDisappear:animated];
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - UI Display

- (void) showSensorInstructionsAfterDelayIfNotConnected {
    
    double delayInSeconds = kWaitForSensorConnectInterval;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        // if we are still connecting, the let's show the ui
        if ( self.isDisplaying ) {
            SensoPlexState state = self.sensoPlex.state;
            if ( state != SensoPlexReady && state != SensoPlexConnecting ) {
                [self promptUserToTurnOnSensor];
            }
        }
    });
}

// show a status message (for a specified amount of time before hiding
- (void) showStatus:(NSString*)status for:(NSTimeInterval)forTime {
    if ( !self.isDisplaying )
        return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        static int statusID = 0;
        self.statusLabel.text = status;
        self.statusLabel.hidden = NO;
        
        int idOfThisStatus = ++statusID;
        
        double delayInSeconds = forTime;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            if ( idOfThisStatus == statusID )
                self.statusLabel.hidden = YES;
        });
    });
}

- (void) promptUserToTurnBluetoothOn {
    self.bluetoothInstructionsLabel.hidden = NO;
    self.sensorInstructionsLabel.hidden = YES;
}

- (void) promptUserToTurnOnSensor {
    self.sensorInstructionsLabel.hidden = NO;
    self.bluetoothInstructionsLabel.hidden = YES;
}

-(void) showDataIsStreaming {
    self.startStreamingDataButton.hidden = YES;
    self.stopStreamingDataButton.hidden = NO;
}

-(void) showDataIsNotStreaming {
    self.startStreamingDataButton.hidden = NO;
    self.stopStreamingDataButton.hidden = YES;
}

- (void) showEmailStreamedDataButton {
    if ( self.bottomToolbar.items.count == 0 ) {
        NSArray *barItems = [NSArray arrayWithObjects:self.leftSpaceButton, self.emailStreamedDataButton, self.rightSpaceButton, nil];
        [self.bottomToolbar setItems:barItems animated:YES];
    }
}

- (void) hideEmailStreamedDataButton {
    self.bottomToolbar.items = nil;
}

#pragma mark - UI Actions

-(IBAction) toggleLED:(id)sender {
    @try {
        // let's toggle through the states for testing
        static SensoPlexLEDState ledState = LEDGreen;
        [self.sensoPlex setLED:ledState];
        if ( ledState == LEDGreen )
            ledState = LEDRed;
        else if ( ledState == LEDRed )
            ledState = LEDSystemControl;
        else if ( ledState == LEDSystemControl )
            ledState = LEDGreen;
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to set the LED.  %@", exception.description);
    }
}

-(IBAction) startStreamingData:(id)sender {
    @try {
        self.sensoPlex.sensorDataDelegate = self;
        BOOL res = [self.sensoPlex startCapturingData:nil];
        res |= [self.sensoPlex setLED:LEDGreen];
        
        if ( res ) {
            // let's update the ui to show the data capture
            [self showDataIsStreaming];
        } else {
            [self showDataIsNotStreaming];
        }
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to start streaming data.  %@", exception.description);
    }
}

-(IBAction) stopStreamingData:(id)sender {
    @try {
        BOOL res = [self.sensoPlex stopCapturingData];
        res |= [self.sensoPlex setLED:LEDRed];
        self.sensoPlex.sensorDataDelegate = nil;
        
        if ( res ) {
            
            // let's update the ui to show that the data capture is stopped
            [self showDataIsNotStreaming];
            
            // let's auto-show the email screen if we captured data
            if ( self.sensoPlex.sensorData ) {
                
                // let the user email
                [self showEmailStreamedDataButton];
            }
        }
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to stop data capture.  %@", exception.description);
    }
}

-(IBAction) getFirmwareVersion:(id)sender {
    @try {
        [self.sensoPlex getFirmwareVersion];
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to get the Firmware Version.  %@", exception.description);
    }
}

-(IBAction) getStatus:(id)sender {
    @try {
        [self.sensoPlex getStatus];
        
        // optional other commands to send once / if implemented
        //[self.sensoPlex getTemperature];
        //[self.sensoPlex getPressure];
        //[self.sensoPlex getSystemTime];
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to get SP-10BN Status.  %@", exception.description);
    }
}

-(IBAction) emailStreamedData:(id)sender {

    // make sure the current device supports email
    if ( ![MFMailComposeViewController canSendMail] ) {
        LogError(@"Unable to email sensor data.  Sending Mail is not available.");
        [self showStatus:@"Please enable an email account on this device." for:kDefaultStatusInterval];
        return;
    }
    
    // setup our mail composer
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    picker.mailComposeDelegate = self;
    [picker setSubject:@"Sensor Data"];
    
    // Set up recipients
    NSArray *toRecipients = nil;
    NSArray *ccRecipients = nil;
    NSArray *bccRecipients = nil;
    [picker setToRecipients:toRecipients];
    [picker setCcRecipients:ccRecipients];
    [picker setBccRecipients:bccRecipients];
    
    // Attach the sensor data to the email
    NSString *path = [self.sensoPlex serializeSensorData];
    NSData *sensorData = [NSData dataWithContentsOfFile:path];
    [picker addAttachmentData:sensorData mimeType:@"data/txt" fileName:@"sensor-data.csv"];
    
    // add our log file as well for debugging)
    NSData *logData = [NSData dataWithContentsOfFile:[MoLogger logger].logFileLocation];
    [picker addAttachmentData:logData mimeType:@"data/txt" fileName:@"log-file.txt"];
    
    // add our ble packet data if we are logging packet data
    BOOL isLogBLEPacketsEnabled = kLogBLEPackets;
    if ( isLogBLEPacketsEnabled ) {
        NSData *packetData = [NSData dataWithContentsOfFile:[SSPacketLogger packetLogger].logFileLocation];
        [picker addAttachmentData:packetData mimeType:@"data/txt" fileName:@"packets.txt"];
    }
    
    // provide message body text
    NSString *emailBody = [NSString stringWithFormat:@"Captured sensor data.  %i Measurements.",
                           self.sensoPlex.sensorData.count];
    [picker setMessageBody:emailBody isHTML:NO];
    
    // show the mail compose view
    [self presentViewController:picker animated:YES completion:NULL];
}


#pragma mark - SensoPlex

- (void) initializeSensoPlex {
    if( !self.sensoPlex ) {
        SensoPlex *sensoPlex = [[SensoPlex alloc] init];
        
        self.sensoPlex = sensoPlex;
        
        // remove any saved sensor data so that we start from scratch each time
        if ( !deletedOldSerializedSensorData ) {
            [self.sensoPlex deleteAllSerializedSensorData];
            deletedOldSerializedSensorData = YES;
        }
    }
    
    // optionally turn on BLE packet logging
    BOOL isLogBLEPacketsEnabled = kLogBLEPackets;
    self.sensoPlex.logBLEPackets = isLogBLEPacketsEnabled;
    
    self.sensoPlex.delegate = self;
}

- (void) cleanupSensoPlex {
    [self.sensoPlex stopScanningForBLEPeripherals];
    [self.sensoPlex cleanup];
    self.sensoPlex = nil;
}


#pragma mark - SensoPlexDelegate

- (void) showConnectionState:(SensoPlexState) state {
    
    switch (state) {
        case SensoPlexConnecting: {
            if ( ![self.sensorConnectingProgressView isAnimating] )
                [self.sensorConnectingProgressView startAnimating];
            
            _sensorConnectedLabel.text = @"connecting...";
            _sensorConnectedImage.image = [UIImage imageNamed:@"Sensor Disconnected"];
            _bluetoothInstructionsLabel.hidden = YES;
            _sensorInstructionsLabel.hidden = YES;
            
            // show our sensor instructions after a bit if we are not able to find a sensor
            [self showSensorInstructionsAfterDelayIfNotConnected];
            break;
        }
        case SensoPlexReady: {
            [self.sensorConnectingProgressView stopAnimating];
            _sensorConnectedLabel.text = @"connected";
            _sensorConnectedImage.image = [UIImage imageNamed:@"Sensor Connected"];
            
            _sensorInstructionsLabel.hidden = YES;
            _bluetoothInstructionsLabel.hidden = YES;
            
            break;
        }
        case SensoPlexDisconnected: {
            _sensorConnectedLabel.text = @"not connected";
            _sensorConnectedImage.image = [UIImage imageNamed:@"Sensor Disconnected"];
            
            _bluetoothInstructionsLabel.hidden = YES;
            
            // tell the user
            _sensorInstructionsLabel.hidden = YES;
            
            // let's wait a bit and then tell the user to power on if the sensor was not connected
            double delayInSeconds = kWaitForSensorConnectInterval;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                if ( state != SensoPlexReady && state != SensoPlexConnecting ) {
                    [self showSensorInstructionsAfterDelayIfNotConnected];
                }
            });
            
            // let's try and re-connect
            [self.sensoPlex scanForBLEPeripherals];
            
            break;
        }
        case SensoPlexFailedToConnect: {
            _sensorConnectedLabel.text = @"failed to connect";
            _sensorConnectedImage.image = [UIImage imageNamed:@"Sensor Disconnected"];
            
            _sensorInstructionsLabel.hidden = NO;
            _bluetoothInstructionsLabel.hidden = YES;
            
            // show our sensor instructions after a bit if we are not able to find a sensor
            [self showSensorInstructionsAfterDelayIfNotConnected];
            break;
        }
        case SensoPlexScanning: {
            if ( ![self.sensorConnectingProgressView isAnimating] )
                [self.sensorConnectingProgressView startAnimating];
            _sensorConnectedLabel.text = @"searching for sensor...";
            _sensorConnectedImage.image = [UIImage imageNamed:@"Sensor Disconnected"];
        
            _bluetoothInstructionsLabel.hidden = YES;
            
            // show our sensor instructions after a bit if we are not able to find a sensor
            // unless we just told the user that they were disconnected
            [self showSensorInstructionsAfterDelayIfNotConnected];
            break;
        }
        case SensoPlexBluetoothError: {
            [self.sensorConnectingProgressView stopAnimating];
            _sensorConnectedLabel.text = NSLocalizedString(@"Bluetooth not turned on...", @"Bluetooth not turned on...");;
            _sensorConnectedImage.image = [UIImage imageNamed:@"Sensor Disconnected"];
            
            _sensorInstructionsLabel.hidden = YES;
            
            // this seems like something we should tell the user as well (one time)
            static BOOL promptedUserToTurnOnBluetooth = NO;
            if ( !promptedUserToTurnOnBluetooth ) {
                [self promptUserToTurnBluetoothOn];
                promptedUserToTurnOnBluetooth = YES;
            } else {
                _bluetoothInstructionsLabel.hidden = NO;
            }
        }
        default:
            break;
    }
    
    if ( state == SensoPlexReady ) {
        self.startStreamingDataButton.hidden = NO;
        self.toggleLEDButton.hidden = NO;
        self.getFirmwareVersionButton.hidden = NO;
        self.getStatusButton.hidden = NO;
        self.stopStreamingDataButton.hidden = YES;
        self.sensorInstructionsLabel.hidden = YES;
        self.bluetoothInstructionsLabel.hidden = YES;
    } else {
        self.startStreamingDataButton.hidden = YES;
        self.stopStreamingDataButton.hidden = YES;
        self.toggleLEDButton.hidden = YES;
        self.getFirmwareVersionButton.hidden = YES;
        self.getStatusButton.hidden = YES;
    }
}

// connection state callbacks
-(void) onSensoPlexConnectStateChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( self.isDisplaying ) {
            SensoPlexState state = self.sensoPlex.state;
            [self showConnectionState:state];
        }
    });
}

// optional to control which SensoPlex peripheral to connect to
// in case the client only wants to connect to a peripheral with
// a specific Identifier
-(BOOL) shouldConnectToSensoPlexPeripheral:(CBPeripheral*)peripheral {
    // we will connect to any SensoPlex peripheral that is discovered
    return YES;
}

// optional callback that gets called when the firmware version has
// been retrieved.
// use the SensoPlex.firmwareVersion property to get the firmware version
-(void) onFirmwareVersionRetrieved {
    [self showStatus:[NSString stringWithFormat:@"Firmware Version: %@", self.sensoPlex.firmwareVersion] for:kDefaultStatusInterval];
}

// optional callback when we retrieve battery status information
// use the SensoPlex.batteryVolts and SensoPlex.isBatteryCharging to
// get the current battery information
-(void) onBatteryStatusRetrieved {
    NSString *msg = [NSString stringWithFormat:@"Battery: %0.2f volts.  %@",
                     self.sensoPlex.batteryVolts,
                     self.sensoPlex.isBatteryCharging ? @"Charging" : @"Not Charging"];
    [self showStatus:msg for:kDefaultStatusInterval];
}

#pragma mark - SensoPlexSensorDataDelegate

- (void) onSensorData:(SensorData*) sensorData {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL showDebugSensorInfo = YES;
        
        // every so often, show the data as well as the number of measurements
        int dataCount = self.sensoPlex.sensorData.count;
        if ( dataCount > 0 && dataCount % kUIPacketRefreshPeriod == 0 ) {
            if ( showDebugSensorInfo ) {
                
                NSString *debugStr = [NSString stringWithFormat:@"%i Measurements\nA: (%0.2lf,%0.2lf,%0.2lf)\nG: (%0.2lf,%0.2lf,%0.2lf)\nTemp: %0.2f°C, Battery: %0.1fV",
                                      dataCount,
                                      sensorData.accelerometerX, sensorData.accelerometerY, sensorData.accelerometerZ,
                                      sensorData.gyroscopeX, sensorData.gyroscopeY, sensorData.gyroscopeZ,
                                      sensorData.temperatureInCelsius, sensorData.batteryVolts];
                [self showStatus:debugStr for:kDefaultStatusInterval];
                
            } else {
                [self showStatus:[NSString stringWithFormat:@"%i Measurements", dataCount] for:kDefaultStatusInterval];
            }
        }
    });
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    
    if ( result == MFMailComposeResultSent ) {
        // we sent the data - so let's clear it
        self.sensoPlex.sensorData = nil;
        
        // hide our email button
        [self hideEmailStreamedDataButton];
        
        // remove any saved sensor data that was emailed
        [self.sensoPlex deleteAllSerializedSensorData];
    }
    
    [self dismissViewControllerAnimated:YES completion:NULL];
    
    // if we are not connected, then scan for our peripheral to connect to
    SensoPlexState state = self.sensoPlex.state;
    if ( state == SensoPlexDisconnected || state == SensoPlexFailedToConnect ) {
        [self.sensoPlex scanForBLEPeripherals];
    } else if ( state == SensoPlexReady ) {
        // let's show the start button again
        self.startStreamingDataButton.hidden = NO;
        self.stopStreamingDataButton.hidden = YES;
    }
}

@end
