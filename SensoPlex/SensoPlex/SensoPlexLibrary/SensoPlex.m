//
//  SensoPlex.m
// 
//
//  Created by Jeremy Millers on 7/31/13.
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

#import "SensoPlex.h"
#import "SensoPlex-Constants.h"
#import "MoLogger.h"
#import "SSPacketLogger.h"
#import "SSPacketParser.h"
#import "SensorData.h"

@interface SensoPlex() <CBCentralManagerDelegate, CBPeripheralDelegate, SSPacketParserDelegate>

// our Core Bluetooth Peripheral object that we are connected to and
// can interact with
@property (strong, nonatomic) CBPeripheral          *blePeripheral;

// our Core Bluetooth Manager object that we use to discover peripherals
@property (strong, nonatomic) CBCentralManager      *centralManager;

// the BLE Write Service that we discover
@property (strong, nonatomic) CBService             *writeService;

// the BLE Characteristic that we discover that we can use to write
// or send commands down on
@property (strong, nonatomic) CBCharacteristic      *writeCharacteristic;

// the BLE Characteristic that we discover and enable notification on
// so that we can receive the BLE asynchronous notification callbacks
@property (strong, nonatomic) CBCharacteristic      *notifyCharacteristic;

// the BLE Characteristic that we discover and enable indications on
// (we don't use these currently)
@property (strong, nonatomic) CBCharacteristic      *indicateCharacteristic;

// any BLE packet data that has been received and is queued up to parse
@property (strong, nonatomic) NSMutableData         *packetDataToParse;

// the Packet Parser that we use to parse the raw BLE packets
@property (strong, nonatomic) SSPacketParser        *packetParser;

// our parsing queue that we use to parse the packet data asynchronously
// from where we receive the BLE packet data
@property (strong, nonatomic) dispatch_queue_t      parsingQueue;

@property (strong, nonatomic) NSLock                *packetDataLock;
@property (strong, nonatomic) NSCondition           *parsingCondition;
@property (nonatomic, assign) BOOL                  parseReceivedDataInParseLoop;

// flag that we set to recognize that we want to scan for peripherals as
// soon as our Core Bluetooth Manager is ready if we need to initialize
// our Core Bluetooth Manager
@property (assign) BOOL startScanningWhenReady;

@end

@implementation SensoPlex

#pragma mark - BLE Discovery / Scanning

// start scanning for BLE peripherals to connect to
- (void) scanForBLEPeripherals {
    
    // set our flag so that we know to scan as soon as the
    // Central Manager is ready
    self.startScanningWhenReady = YES;
    
    // initialize our bluetooth if we need to
    if ( !self.centralManager ) {
        [self initializeBluetooth];
    } else {
        // otherwise just scan since bluetooth is already initialized
        [self scan];
    }
}

// stop scanning for BLE peripherals
- (void) stopScanningForBLEPeripherals {
    // if central manager is powered on, then stop the scan
    CBCentralManagerState state = self.centralManager.state;
    if ( state == CBCentralManagerStatePoweredOn ) {
        [self.centralManager stopScan];
        Log(@"Scanning stopped");
    }
    
    // reset our flag
    self.startScanningWhenReady = NO;
    
    // if we have connected and discovered our write characteristic,
    // then recognize that we are ready, otherwise recognize that
    // we are not connected
    if ( self.state == SensoPlexScanning ) {
        if ( self.writeCharacteristic )
            self.state = SensoPlexReady;
        else
            self.state = SensoPlexDisconnected;
    }
}

#pragma mark - BLE Commands

// retrieve the firmware version (asyncronously)
// the SensoPlexDelegate:onFirmwareVersionRetrieved callback gets made
// when the firmware version is retrieved
-(BOOL) getFirmwareVersion {
    
    @try {
        Log(@"Getting Firmware Version...");
        
        // if we don't have our write characteristic, then we can't send
        // commands down
        if ( !self.writeCharacteristic ) {
            LogError(@"No Write Characteristic available to get firmware version.");
            return NO;
        }
        
        // write our "Get Firmware" command to the write characteristic
        CBCharacteristicWriteType writeType = CBCharacteristicWriteWithResponse;
        CBCharacteristic *characteristic = self.writeCharacteristic;
        CBUUID *uuid = characteristic.UUID;
        const char *charDesc = [self CBUUIDToString:uuid];
        
        Byte bytes[2] = {(Byte)BLE_CMD_VERSION, 0};
        NSData *cmdData = [NSData dataWithBytes:&bytes length:2];
        if ( self.logBLEStats )
            Log(@"** Writing %@ to %s", cmdData, charDesc);
        [self.blePeripheral writeValue:cmdData forCharacteristic:characteristic type:writeType];
        
        return YES;
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to get the firmware version.  %@", exception.description);
        return NO;
    }
}

// get the current temperature
- (BOOL) getTemperature {
    @try {
        Log(@"Getting Temperature...");
        
        if ( !self.writeCharacteristic ) {
            LogError(@"No Characteristic available to get temperature.");
            return NO;
        }
        
        CBCharacteristicWriteType writeType = CBCharacteristicWriteWithResponse;
        CBCharacteristic *characteristic = self.writeCharacteristic;
        CBUUID *uuid = characteristic.UUID;
        const char *charDesc = [self CBUUIDToString:uuid];
        
        Byte bytes[2] = {(Byte)BLE_CMD_GET_TEMPERATURE, 0};
        NSData *cmdData = [NSData dataWithBytes:&bytes length:2];
        if ( self.logBLEStats )
            Log(@"** Writing %@ to %s", cmdData, charDesc);
        [self.blePeripheral writeValue:cmdData forCharacteristic:characteristic type:writeType];
        
        return YES;
        
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to get the temperature.  %@", exception.description);
        return NO;
    }
}

// get the current pressure
- (BOOL) getPressure {
    @try {
        Log(@"Getting Pressure...");
        
        if ( !self.writeCharacteristic ) {
            LogError(@"No Characteristic available to get pressure.");
            return NO;
        }
        
        CBCharacteristicWriteType writeType = CBCharacteristicWriteWithResponse;
        CBCharacteristic *characteristic = self.writeCharacteristic;
        CBUUID *uuid = characteristic.UUID;
        const char *charDesc = [self CBUUIDToString:uuid];
        
        Byte bytes[2] = {(Byte)BLE_CMD_GET_PRESSURE, 0};
        NSData *cmdData = [NSData dataWithBytes:&bytes length:2];
        if ( self.logBLEStats )
            Log(@"** Writing %@ to %s", cmdData, charDesc);
        [self.blePeripheral writeValue:cmdData forCharacteristic:characteristic type:writeType];
        
        return YES;
        
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to get the pressure.  %@", exception.description);
        return NO;
    }
}

// get the current system time
- (BOOL) getSystemTime {
    @try {
        Log(@"Getting System Time...");
        
        if ( !self.writeCharacteristic ) {
            LogError(@"No Characteristic available to get system time.");
            return NO;
        }
        
        CBCharacteristicWriteType writeType = CBCharacteristicWriteWithResponse;
        CBCharacteristic *characteristic = self.writeCharacteristic;
        CBUUID *uuid = characteristic.UUID;
        const char *charDesc = [self CBUUIDToString:uuid];
        
        Byte bytes[2] = {(Byte)BLE_CMD_GETRTC, 0};
        NSData *cmdData = [NSData dataWithBytes:&bytes length:2];
        if ( self.logBLEStats )
            Log(@"** Writing %@ to %s", cmdData, charDesc);
        [self.blePeripheral writeValue:cmdData forCharacteristic:characteristic type:writeType];
        
        return YES;
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to get the system time.  %@", exception.description);
        return NO;
    }
}

// get the current status of the SP-10BN Module
- (BOOL) getStatus {
    @try {
        Log(@"Getting Status...");
        
        if ( !self.writeCharacteristic ) {
            LogError(@"No Characteristic available to get system time.");
            return NO;
        }
        
        CBCharacteristicWriteType writeType = CBCharacteristicWriteWithResponse;
        CBCharacteristic *characteristic = self.writeCharacteristic;
        CBUUID *uuid = characteristic.UUID;
        const char *charDesc = [self CBUUIDToString:uuid];
        
        Byte bytes[2] = {(Byte)BLE_CMD_STATUS, 0};
        NSData *cmdData = [NSData dataWithBytes:&bytes length:2];
        if ( self.logBLEStats )
            Log(@"** Writing %@ to %s", cmdData, charDesc);
        [self.blePeripheral writeValue:cmdData forCharacteristic:characteristic type:writeType];
        
        return YES;
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to get the SensoPlex status.  %@", exception.description);
        return NO;
    }
}

// change the LED state
-(BOOL) setLED:(SensoPlexLEDState)ledState {
    @try {
        Log(@"Setting LED");
        
        if ( !self.writeCharacteristic ) {
            LogError(@"No Characteristic available to set LED.");
            return NO;
        }
        
        // Determine the correct command byte to send
        Byte lightColor = (Byte)BLE_CMD_LEDSYSCONTROL;
        if ( ledState == LEDGreen )
            lightColor = (Byte)BLE_CMD_LEDGREEN;
        else if ( ledState == LEDRed )
            lightColor = (Byte)BLE_CMD_LEDRED;
        
        // create and send our "SET LED" command down
        Byte bytes[2] = {(Byte)BLE_CMD_SETLED, lightColor};
        NSData *cmdData = [NSData dataWithBytes:&bytes length:2];
        
        CBUUID *uuid = self.writeCharacteristic.UUID;
        const char *charDesc = [self CBUUIDToString:uuid];
        
        if ( self.logBLEStats )
            Log(@"** Writing %@ to %s", cmdData, charDesc);
        [self.blePeripheral writeValue:cmdData forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithResponse];
        
        return YES;
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to set the LED.  %@", exception.description);
        return NO;
    }
}

// start capturing sensor data
-(BOOL) startCapturingData:(id)options {
    @try {
        if ( !self.writeCharacteristic ) {
            LogError(@"No Characteristic available to capture data.");
            return NO;
        }
        
        Log(@"* Starting Data Capture...");
        
        if ( self.logBLEPackets ) {
            [[SSPacketLogger packetLogger] logPacket:@"******* NEW DATA CAPTURE *********"];
        }
        
        // clear any sensor data that we may have accumulated from a
        // previous capture session
        if ( self.sensorData )
            [self.sensorData removeAllObjects];
        
        // create our packet data lock for synchronization if we need to
        if ( !self.packetDataLock )
            self.packetDataLock = [[NSLock alloc] init];
        
        // send our command down to start capturing data
        Byte bytes[2] = {(Byte)BLE_CMD_STREAMENABLE, 0x01};
        NSData *cmdData = [NSData dataWithBytes:&bytes length:2];
        [self.blePeripheral writeValue:cmdData forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithResponse];
        
        self.isCapturingData = YES;
        
        return YES;
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to start capturing data.  %@", exception.description);
        return NO;
    }
}

// stop capturing sensor data
-(BOOL) stopCapturingData {
    @try {
        if ( !self.writeCharacteristic ) {
            LogError(@"No Characteristic available to stop data capture.");
            return NO;
        }
        
        Log(@"* Stopping Data Capture...");
        Byte bytes[2] = {(Byte)BLE_CMD_STREAMENABLE, 0x0};
        NSData *cmdData = [NSData dataWithBytes:&bytes length:2];
        [self.blePeripheral writeValue:cmdData forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithResponse];
        
        self.isCapturingData = NO;
        
        return YES;
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to stop data capture.  %@", exception.description);
        return NO;
    }
}

#pragma mark - Serialization of Sensor Data

- (NSString *) getPathForSerializedData {
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *sensorDirectory = [documentsDirectory stringByAppendingPathComponent:@"sensor-data"];
    return sensorDirectory;
}

// serialize the captured sensor data serialized in csv format to a file
// (uses default "sensor-data.csv" for the filename
- (NSString *) serializeSensorData {
    return [self serializeSensorData:nil];
}

// serialize the captured sensor data serialized in csv format to a file
// returns the full filename with path serialized to.
- (NSString *) serializeSensorData:(NSString*)fileName {
    
    // provide a default filename if we weren't given one
    if ( !fileName.length )
        fileName = @"sensor-data.csv";
    
    // make sure our filename ends in .csv
    if ( [fileName rangeOfString:@".csv"].location == NSNotFound )
        fileName = [NSString stringWithFormat:@"%@.csv", fileName];
    
    // get the file path
    NSString *sensorDirectory = [self getPathForSerializedData];
    
    // make sure the path exists
    NSError *error = nil;
    BOOL createdPath = [[NSFileManager defaultManager] createDirectoryAtPath:sensorDirectory withIntermediateDirectories:YES attributes:nil error:&error];
    if ( !createdPath ) {
        LogError(@"Unable to create the sensor data directory %@.  %@",
                 sensorDirectory, error.description);
    }
    
    // make our full filename from the path
    NSString *fullFileName = [sensorDirectory stringByAppendingPathComponent:fileName];
    
    // create file
    BOOL res = [[NSFileManager defaultManager] createFileAtPath:fullFileName contents:nil attributes:nil];
    if ( !res ) {
        LogError(@"Unable to create a sensor data file to serialize to.");
        return nil;
    }
    
    // append text to file
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:fullFileName];
    
    // write our headers
    [file writeData:[@"Sequence, Timestamp, , Accelerometer (G's), , , , Gyroscope (Degrees per second), , , , Magnetometer, , , , Quaternion, , , , , Temperature, , Pressure, , Linear Acceleration, , , , Euler Angles, , , , Rotation Matrix, , , , , , , , , , Heading, , Battery Volts, , BLE RSSI, , BLE State, \n , , , X, Y, Z, , X, Y, Z, , X, Y, Z, , W, X, Y, Z, , , , , , X, Y, Z, , X, Y, Z, , , , , \n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    
    // iterate through each SensorData object and output to the file
    int i = 0;
    for ( SensorData *sensorData in self.sensorData ) {
        NSMutableString *content = [[NSMutableString alloc] initWithString:@""];
        if ( i != 0 )
            [content appendString:@"\n"];
        [content appendString:[NSString stringWithFormat:@"%i", i]];
        
        // Timestamp
        [content appendString:[NSString stringWithFormat:@", %i, ", (int)sensorData.timestamp]];
        
        // Accelerometer
        [content appendString:[NSString stringWithFormat:@", %lf, %lf, %lf, ",
                               sensorData.accelerometerX,
                               sensorData.accelerometerY,
                               sensorData.accelerometerZ]];
        
        // Gyroscope
        [content appendString:[NSString stringWithFormat:@", %lf, %lf, %lf, ",
                               sensorData.gyroscopeX,
                               sensorData.gyroscopeY,
                               sensorData.gyroscopeZ]];
        
        // Compass / Magnetometer
        [content appendString:[NSString stringWithFormat:@", %lf, %lf, %lf, ",
                               sensorData.magnetometerX,
                               sensorData.magnetometerY,
                               sensorData.magnetometerZ]];
        
        // Quaternions
        [content appendString:[NSString stringWithFormat:@", %lf, %lf, %lf, %lf, ",
                               sensorData.quaternionW,
                               sensorData.quaternionX,
                               sensorData.quaternionY,
                               sensorData.quaternionZ]];
        
        // Temperature & Pressure
        [content appendString:[NSString stringWithFormat:@", %0.2f, ", sensorData.temperatureInCelsius]];
        [content appendString:[NSString stringWithFormat:@", %i, ", (int)sensorData.pressure]];
        
        // Linear Acceleration
        [content appendString:[NSString stringWithFormat:@", %lf, %lf, %lf, ",
                               sensorData.linearAccelerationX,
                               sensorData.linearAccelerationY,
                               sensorData.linearAccelerationZ]];
        
        // Euler Angles
        [content appendString:[NSString stringWithFormat:@", %lf, %lf, %lf, ",
                               sensorData.eulerX,
                               sensorData.eulerY,
                               sensorData.eulerZ]];
        
        // Rotation Matrix
        [content appendString:[NSString stringWithFormat:@", %lf, %lf, %lf, %lf, %lf, %lf, %lf, %lf, %lf, ",
                               sensorData.rotationMatrixA,
                               sensorData.rotationMatrixB,
                               sensorData.rotationMatrixC,
                               sensorData.rotationMatrixD,
                               sensorData.rotationMatrixE,
                               sensorData.rotationMatrixF,
                               sensorData.rotationMatrixG,
                               sensorData.rotationMatrixH,
                               sensorData.rotationMatrixI]];
        
        // Heading
        [content appendString:[NSString stringWithFormat:@", %lf, ", sensorData.heading]];
        
        // Battery
        [content appendString:[NSString stringWithFormat:@", %0.2f, ", sensorData.batteryVolts]];
        
        // BLE Info
        [content appendString:[NSString stringWithFormat:@", %i, ", (int)sensorData.bleRSSI]];
        [content appendString:[NSString stringWithFormat:@", %i, ", (int)sensorData.bleState]];

        [file writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
        ++i;
    }
    
    [file closeFile];
    
    return fullFileName;
}

// delete all saved sensor data files
- (BOOL) deleteAllSerializedSensorData {
    BOOL success = YES;
    @try {
        NSString *path = [self getPathForSerializedData];
        NSFileManager *fileMgr = [NSFileManager defaultManager];
        NSError *error = nil;
        NSArray *files = [fileMgr contentsOfDirectoryAtPath:path error:&error];
        for ( NSString *fileName in files ) {
            NSString *fullFileName = [path stringByAppendingPathComponent:fileName];
            BOOL res = [fileMgr removeItemAtPath:fullFileName error:&error];
            if ( !res ) {
                LogError(@"Unable to delete sensor data file %@.  %@",
                         fullFileName, error.description);
                success = NO;
            }
        }
    }
    @catch (NSException *exception) {
        LogError(@"Error deleting all sensor data files.  %@", exception.description);
        success = NO;
    }
    @finally {
        return success;
    }
}

#pragma mark - Packet Parsing

- (void) signalParsingQueueToWakeUp {
    [self.parsingCondition lock];
    [self.parsingCondition signal];
    [self.parsingCondition unlock];
}

- (void) parseLoop {
    
    BOOL locked = NO;
    BOOL conditionLocked = NO;
    @try {
        // setup a loop that will loop trying to parse.
        //
        // it will wait for a signal that there is data, and
        // then parse that data and then go back to waiting
        while ( self.parseReceivedDataInParseLoop ) {
            
            // acquire our data lock since we will be accessing the data
            [self.packetDataLock lock];
            locked = YES;
            
            // check to see if we have data to parse
            if ( self.packetDataToParse.length ) {
                // let's parse this data
                [self parsePacketData:self.packetDataToParse];
                
                // then clear the data just parsed
                [self.packetDataToParse setLength:0];
            }
            
            // now release our lock(s) (we will re-acquire them in the next loop)
            [self.packetDataLock unlock];
            locked = NO;
            
            // acquire our condition lock first
            [self.parsingCondition lock];
            conditionLocked = YES;
            
            // wait for data to be available
            [self.parsingCondition wait];
            
            // release our parsing condition lock
            [self.parsingCondition unlock];
            conditionLocked = NO;
        }
    }
    @catch (NSException *exception) {
        LogError(@"Error in parse loop.  %@", exception.description);
    }
    @finally {
        if ( locked )
            [self.packetDataLock unlock];
        
        if ( conditionLocked )
            [self.parsingCondition unlock];
        
        // get rid of our parsing queue, since we need to restart it
        self.parsingQueue = nil;
    }
}

// parse our received data
-(void) parseReceivedData {
    BOOL locked = NO;
    @try {
        // acquire our packet lock so that we don't step on any processing going on
        [self.packetDataLock lock];
        locked = YES;
        
        // parse our packet data
        [self parsePacketData:self.packetDataToParse];
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to parse received data.  %@", exception.description);
    } @finally {
        if ( locked ) {
            [self.packetDataLock unlock];
            locked = NO;
        }
    }
}

// parse specified packet data
- (void) parsePacketData:(NSMutableData*)packetData {
    // don't do anything if we don't have any data
    int dataLength = packetData.length;
    if ( !packetData || dataLength == 0 ) {
        Log(@"No Data to parse.");
        // we don't have data to parse - it must have already been parsed
        // as part of another block execution on our async queue
        return;
    }
    
    // create our Packet Parser if we need to
    if ( !self.packetParser ) {
        self.packetParser = [[SSPacketParser alloc] init];
        self.packetParser.delegate = self;
        self.packetParser.logPackets = self.logBLEPackets;
    }
    
    if ( self.firmwareVersion )
        self.packetParser.firmwareVersion = self.firmwareVersion;
    
    // feed the bytes to our packet parsing one at a time
    const Byte *bytesToParse = (Byte*)packetData.bytes;
    const Byte *currentByte = bytesToParse;
    
    for ( int i = 0; i < dataLength; i++ ) {
        Byte byte = *currentByte++;
        [self.packetParser processPacketByte:byte];
    }
    
    // clear the packet data since we just parsed all of the bytes in it
    [packetData setLength:0];
}

#pragma mark - SSPacketParserDelegate

- (void) onFirmwareVersionParsed:(NSString*)fwVersion {
    self.firmwareVersion = fwVersion;
    
    Log(@"Firmware Version: %@", fwVersion);
    
    // let our delegate know if we have one that wants to know
    if ( self.delegate && [self.delegate respondsToSelector:@selector(onFirmwareVersionRetrieved)]) {
        [self.delegate onFirmwareVersionRetrieved];
    }
}

- (void) onSensorDataParsed:(SensorData *)data {
    // let's add this to our sensor data
    if ( !self.sensorData )
        self.sensorData = [[NSMutableArray alloc] init];
    
    [self.sensorData addObject:data];
    
    // if we have a delegate monitoring the sensor data, then send this to them
    if ( self.sensorDataDelegate ) {
        [self.sensorDataDelegate onSensorData:data];
    }
}

- (void) onSensorStatusParsed:(Byte)sensorModel chargerState:(Byte)chargerState
                 batteryVolts:(float)batteryVolts {
    self.batteryVolts = batteryVolts;
    self.isBatteryCharging = chargerState != 0;
    Log(@"Battery: %f volts.  %@", self.batteryVolts,
        self.isBatteryCharging ? @"Charging" : @"Not Charging");
    
    // let our delegate know
    if ( self.delegate && [self.delegate respondsToSelector:@selector(onBatteryStatusRetrieved)] ) {
        [self.delegate onBatteryStatusRetrieved];
    }
}

#pragma mark - BLE

- (void) initializeBluetooth {
    self.logBLEStats = NO;
    
    // Start up the CBCentralManager
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:
                       dispatch_get_main_queue()];
    
    // And somewhere to store the incoming data
    _packetDataToParse = [[NSMutableData alloc] init];
}

/** Call this when things either go wrong, or you're done with the connection.
 *  This cancels any subscriptions if there are any, or straight disconnects if not.
 *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
 */
- (void)cleanup
{
    // Don't do anything if we're not connected
    if ( !self.blePeripheral.state != CBPeripheralStateConnected ) {
        return;
    }
    
    // unsubscribe to any characteristics on the peripheral
    if (self.blePeripheral.services != nil) {
        for (CBService *service in self.blePeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if (characteristic.isNotifying) {
                        // It is notifying, so unsubscribe
                        [self.blePeripheral setNotifyValue:NO forCharacteristic:characteristic];
                    }
                }
            }
        }
    }
    
    // let's disconnect from the peripheral as well
    [self.centralManager cancelPeripheralConnection:self.blePeripheral];
    
    // end our parsing loop
    self.parseReceivedDataInParseLoop = NO;
    [self.parsingCondition lock];
    [self.parsingCondition signal];
    [self.parsingCondition unlock];
}


- (BOOL) shouldConnectToPeripheral:(CBPeripheral*)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    // we check against the name
    NSString *name = peripheral.name;
    NSString *advertisedName = [advertisementData objectForKey:@"kCBAdvDataLocalName"];
    BOOL connect = NO;
    if ( [name isEqualToString:@"SP-10BN"] ) {
        connect = YES;
    } else if ( [advertisedName isEqualToString:@"SP-10BN"] ) {
        connect = YES;
    }
    else {
        Log(@"Not connecting to Bluetooth LE peripheral: %@", peripheral);
        connect = NO;
    }
    
    // if this is a SensoPlex peripheral, and we have a delegate that wants
    // the final say on whether we connect, then ask them
    if ( connect && self.delegate && [self.delegate respondsToSelector:@selector(shouldConnectToSensoPlexPeripheral:)] ) {
        connect = [self.delegate shouldConnectToSensoPlexPeripheral:peripheral];
    }
    
    return connect;
}

- (void) onSensoPlexReady {
    self.state = SensoPlexReady;
    
    // let's get the firmware version so that we have it
    [self getFirmwareVersion];
    
    // let's get the status as well - for battery, etc.
    [self getStatus];
    
    // let our delegate know
    [self notifyDelegateOfConnectStateChange];
}


#pragma mark - Bluetooth Central Methods

// Scan for peripherals
- (void)scan
{
    self.state = SensoPlexScanning;
    [self notifyDelegateOfConnectStateChange];
    [self.centralManager scanForPeripheralsWithServices:nil//@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]
                                                options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @NO }];
    
    Log(@"Scanning BLE for sensors...");
}

- (void) notifyDelegateOfConnectStateChange {
    if ( self.delegate && [self.delegate respondsToSelector:@selector(onSensoPlexConnectStateChange)]) {
        [self.delegate onSensoPlexConnectStateChange];
    }
}

/** centralManagerDidUpdateState is a required protocol method.
 *  Usually, you'd check for other states to make sure the current device supports LE, is powered on, etc.
 *  In this instance, we're just using it to wait for CBCentralManagerStatePoweredOn, which indicates
 *  the Central is ready to be used.
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    CBCentralManagerState state = central.state;
    Log(@"CBCentralManager State: %i", state);
    
    if (state != CBCentralManagerStatePoweredOn) {
        
        // TODO: deal with all the states correctly
        self.state = SensoPlexBluetoothError;
        if ( self.delegate && [self.delegate respondsToSelector:@selector(onSensoPlexConnectStateChange)]) {
            [self.delegate onSensoPlexConnectStateChange];
        }
        
        return;
    }
    
    // The state must be CBCentralManagerStatePoweredOn...
    
    // start scanning if we were asked to
    if ( self.startScanningWhenReady ) {
        [self scan];
    }
    
}


// This callback comes whenever a peripheral is discovered.
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    // Can reject any where the value is above reasonable range
    //if (RSSI.integerValue > -15) {
    //    return;
    //}
    
    Log(@"Discovered %@ at %@ - Adv data: %@", peripheral.name, RSSI, advertisementData);
    
    if ( [self shouldConnectToPeripheral:peripheral advertisementData:advertisementData RSSI:RSSI] ) {
        
        // Ok, it's in range - have we already seen it?
        if (self.blePeripheral != peripheral ) {
            
            // cancel any previous peripheral connection first?
            //if ( self.discoveredPeripheral )
            //   [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
            
            // save a local copy of the peripheral
            self.blePeripheral = peripheral;
            
            // and connect to this peripheral
            Log(@"Connecting to peripheral %@", peripheral);
            self.state = SensoPlexConnecting;
            [self.centralManager connectPeripheral:peripheral options:nil];
            [self notifyDelegateOfConnectStateChange];
        }
    }
}


// If the connection fails for whatever reason, we need to deal with it.
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    LogError(@"Failed to connect to %@. (%@)", peripheral, [error localizedDescription]);
    self.state = SensoPlexFailedToConnect;
    self.writeCharacteristic = nil;
    self.writeService = nil;
    [self notifyDelegateOfConnectStateChange];
    [self cleanup];
}


// We've connected to the peripheral, now we need to discover the services
//  and characteristics to find the 'write' characteristic.
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    Log(@"Peripheral Connected");
    
    // Stop scanning
    [self stopScanningForBLEPeripherals];
    
    self.state = SensoPlexConnected;
    [self notifyDelegateOfConnectStateChange];
    
    // Clear any data that we may already have
    [self.packetDataToParse setLength:0];
    
    // Make sure we get the discovery callbacks
    peripheral.delegate = self;
    
    // Search for the services that we care about
    [peripheral discoverServices:nil/*@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]*/];
}

// Once disconnection happens, we need to clean up our local copy of the peripheral
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    Log(@"Peripheral Disconnected.  %@", error.localizedDescription);
    self.blePeripheral = nil;
    self.writeCharacteristic = nil;
    self.writeService = nil;
    self.state = SensoPlexDisconnected;
    [self notifyDelegateOfConnectStateChange];
}

#pragma mark - CBPeripheralDelegate

// A BLE Service was discovered
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        LogError(@"Error discovering services: %@", [error localizedDescription]);
        return;
    }
    
    // Discover the characteristic(s) we want...
    
    // Loop through the newly filled peripheral.services array to find
    // the services that we care about
    for (CBService *service in peripheral.services) {
        CBUUID *uuid = service.UUID;
        NSString *desc = uuid.debugDescription;
        if ( self.logBLEStats) {
            Log(@"Discovered Service: \"%s (%@)\".",
                   [self CBUUIDToString:uuid], desc);
        }
        
        // keep track of the "write" service that has the characteristic(s)
        // that we want
        if ( [self compareCBUUID:uuid UUID2:[CBUUID UUIDWithString:BLE_TRANSFER_SERVICE_UUID]] )
            self.writeService = service;
        
        // discover the characteristics for this service as well
        [peripheral discoverCharacteristics:nil//@[[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]
                                 forService:service];
    }
}


// a BLE Characteristic was discovered
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    // Deal with errors (if any)
    if (error) {
        LogError(@"Error discovering characteristics: %@", [error localizedDescription]);
        return;
    }
    
    // Loop through the array, and find the characteristic(s) that we care about
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        CBUUID *suuid = service.UUID;
        NSString *sval = (NSString*)suuid;
        
        CBUUID *uuid = characteristic.UUID;
        NSString *val = uuid.debugDescription;
        
        if ( self.logBLEStats ) {
            Log(@"Discovered characteristic: \"%s (%@)\" for service: \"%@\".",
                       [self CBUUIDToString:uuid], val, sval);
        }
        
        // keep track of the write characteristic that we use to
        // send commands down to SensoPlex
        if ( [self compareCBUUID:uuid UUID2:[CBUUID UUIDWithString:BLE_WRITE_CHARACTERISTIC_UUID]] ) {
            self.writeCharacteristic = characteristic;
        }
        
        
        BOOL setNotifyOn = NO;
        
        // ask to get notified on the characteristic(s) that will be
        // used to send us data
        if ( [self compareCBUUID:uuid UUID2:[CBUUID UUIDWithString:BLE_NOTIFY_CHARACTERISTIC_UUID]] ) {
            self.notifyCharacteristic = characteristic;
            if ( !setNotifyOn ) {
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                setNotifyOn = YES;
            }
        }
        
        // turn on indications if we want them
        if ( [self compareCBUUID:uuid UUID2:[CBUUID UUIDWithString:BLE_INDICATE_CHARACTERISTIC_UUID]] ) {
            self.indicateCharacteristic = characteristic;
            if ( !setNotifyOn ) {
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                setNotifyOn = YES;
            }
        }
        
        // catch all to turn on notifications for all the characteristics
        // that can send notifications
        if ( [self shouldNotifyForCharacteristic:characteristic] ) {
            if ( !setNotifyOn ) {
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                setNotifyOn = YES;
            }
        }
    }
    
    // if we have a write characteristic then we are ready for action
    if ( self.writeCharacteristic ) {
        [self onSensoPlexReady];
    }
}

// callback when BLE Descriptors are discovered for a characteristic
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        LogError(@"Error discovering descriptors for characteristic: %@", [error localizedDescription]);
        return;
    }
}

- (BOOL) shouldNotifyForCharacteristic:(CBCharacteristic*) characteristic {
    return [SensoPlex isCharacteristicNotifiable:characteristic];
}

// Callback when data is written (by us) to a BLE characteristic
-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    CBUUID *uuid = characteristic.UUID;
    NSString *desc = uuid.debugDescription;
    
    if ( error) {
        LogError(@"Error writing value to characteristic for %@.  Current Value: %@.  %@", desc,
                 characteristic.value, [error localizedDescription]);
        return;
    } else {
        if ( self.logBLEStats)
            Log(@"Successfully wrote value (%@) for characteristic: %@", characteristic.value, desc);
    }
}

// BLE Callback when data has arrived via a BLE notification from
// the hardware
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if (error) {
        CBUUID *uuid = characteristic.UUID;
        NSString *desc = uuid.debugDescription;
        LogError(@"Error discovering characteristic value for %@: %@", desc, [error localizedDescription]);
        return;
    }
    
    // get the new data
    NSData *newData = characteristic.value;
    
    // Log it if we are logging
    if ( self.logBLEStats) {
        NSString *msg = [NSString stringWithFormat:@"\n*** Received:\n%@\n\n", newData];
        Log(msg);
    }
    
    if ( self.logBLEPackets ) {
        NSString *msg = [NSString stringWithFormat:@"* Received: %@", newData];
        [[SSPacketLogger packetLogger] logPacket:msg];
    }
    
    // add the data on to what we already have
    BOOL locked = NO;
    @try {
        [self.packetDataLock lock];
        locked = YES;
        
        [self.packetDataToParse appendData:newData];
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to queue up data to parse.  %@", exception.description);
    }
    @finally {
        if ( locked ) {
            [self.packetDataLock unlock];
            locked = NO;
        }
    }
    
    // create our parsing queue that we use to loop through and
    // parse our packet data if we have to
    if ( !self.parsingQueue ) {
        dispatch_queue_t parsingQueue = dispatch_queue_create("com.sweetspot.sensor_parsing_queue", DISPATCH_QUEUE_SERIAL);
        self.parsingQueue = parsingQueue;
        self.parsingCondition = [[NSCondition alloc] init];
        self.parseReceivedDataInParseLoop = YES;
        
        dispatch_async(self.parsingQueue, ^{
            [self parseLoop];
        });
    } else {
        // signal to our parsing queue that we have data
        [self signalParsingQueueToWakeUp];
    }
}

/** The peripheral letting us know whether our subscribe/unsubscribe happened or not
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSString *desc = characteristic.UUID.debugDescription;
    if (error) {
        // this happens on characteristics that it shouldn't for some reason with the
        // SensoPlex hardware and iOS 7 Beta 5. We still get notifications up
        // on the characteristics that we should, so only log this error if we
        // want to get the ble stats
        if ( self.logBLEStats ) {
            LogError(@"Error changing notification state for characteristic: \"%@\". %@",
                     desc, error.localizedDescription);
        }
    }
    
    if ( self.logBLEStats) {
        if (characteristic.isNotifying) {
            // Notification has started
            Log(@"******* Notification ON for %@", desc);
        }
        else {
            // Notification has stopped
            Log(@"*** Notification OFF for %@", desc);
        }
    }
}

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral {
    Log(@"New Peripheral name: %@", peripheral.name);
}


#pragma mark - UUID & Misc BLE functions

+(BOOL) isCharacteristicNotifiable:(CBPeripheral *)peripheral sCBUUID:(CBUUID *)sCBUUID cCBUUID:(CBUUID *) cCBUUID {
    for ( CBService *service in peripheral.services ) {
        if ([service.UUID isEqual:sCBUUID]) {
            for (CBCharacteristic *characteristic in service.characteristics ) {
                if ([characteristic.UUID isEqual:cCBUUID]) {
                    return [self isCharacteristicNotifiable:characteristic];
                }
                
            }
        }
    }
    return NO;
}

+(BOOL) isCharacteristicNotifiable:(CBCharacteristic*)characteristic {
    if (characteristic.properties & CBCharacteristicPropertyNotify)
        return YES;
    else
        return NO;
}

/*
 *  @method CBUUIDToString
 *
 *  @param UUID UUID to convert to string
 *
 *  @returns Pointer to a character buffer containing UUID in string representation
 *
 *  @discussion CBUUIDToString converts the data of a CBUUID class to a character pointer for easy printout using printf()
 *
 */
-(const char *) CBUUIDToString:(CBUUID *) UUID {
    return [[UUID.data description] cStringUsingEncoding:NSStringEncodingConversionAllowLossy];
}


/*
 *  @method UUIDToString
 *
 *  @param UUID UUID to convert to string
 *
 *  @returns Pointer to a character buffer containing UUID in string representation
 *
 *  @discussion UUIDToString converts the data of a CFUUIDRef class to a character pointer for easy printout using printf()
 *
 */
-(const char *) UUIDToString:(CFUUIDRef)UUID {
    if (!UUID) return "NULL";
    CFStringRef s = CFUUIDCreateString(NULL, UUID);
    return CFStringGetCStringPtr(s, 0);
    
}

/*
 *  @method compareCBUUID
 *
 *  @param UUID1 UUID 1 to compare
 *  @param UUID2 UUID 2 to compare
 *
 *  @returns 1 (equal) 0 (not equal)
 *
 *  @discussion compareCBUUID compares two CBUUID's to each other and returns 1 if they are equal and 0 if they are not
 *
 */
-(int) compareCBUUID:(CBUUID *) UUID1 UUID2:(CBUUID *)UUID2 {
    
    if ( [UUID1 isEqual:UUID2] ) {
        return 1;
    } else {
        return 0;
    }
}


@end
