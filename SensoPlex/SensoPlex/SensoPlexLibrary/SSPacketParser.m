//
//  SSPacketParser.m
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

#import "SSPacketParser.h"
#import "SensoPlex-Constants.h"
#import "MoLogger.h"
#import "SSPacketLogger.h"
#import "SensorData.h"

@interface SSPacketParser () {
    // our current checksum while parsing
    Byte chksum;
    
    // information about the firmware version being parsed
    BOOL _checkedFirmwareVersionForStreamOptions;
    BOOL _use12BytesForAccelsAndGyros;
}

@end

@implementation SSPacketParser

- (id) init {
    if ( self = [super init] ) {
        _checkedFirmwareVersionForStreamOptions = NO;
        _use12BytesForAccelsAndGyros = YES;
    }
    
    return self;
}

/*---- PDI receive states ----*/
typedef enum {
    RXSTATE_IDLE = 0,
    RXSTATE_CMD,
    RXSTATE_STF,
    RXSTATE_DATA
} RXSTATES;

/*---- buffer defines ----*/
#define  RXPKTSIZE            256

/*---- static variable declarations ----*/
static Byte RxState = RXSTATE_IDLE;
static int RxIndex;
static Byte RxPacket[RXPKTSIZE];

/****************************************************************
 CALL:    processPacketByte()
 INTRO:   This routine processes receive PDI packets.
 INPUT:   c     - character to process
 OUTPUT:  nothing
 ****************************************************************/
-(void) processPacketByte:(Byte) c {
    
    //static Byte chksum;
    switch( RxState ) {
        case RXSTATE_IDLE: {
            if( c == PDI_START_OF_PACKET ) {
                RxState = RXSTATE_CMD;
            }
            break;
        }
        case RXSTATE_CMD: {
            RxPacket[0] = c;
            chksum = c;
            RxIndex = 1;
            RxState = RXSTATE_DATA;
            break;
        }
        case RXSTATE_STF: {
            RxPacket[RxIndex] = c;
            chksum += c;
            RxIndex++;
            RxState = RXSTATE_DATA;
            break;
        }
        case RXSTATE_DATA: {
            switch( c ) {
                case PDI_BYTE_STUFFING: {
                    RxState = RXSTATE_STF;
                    chksum += PDI_BYTE_STUFFING;
                    break;
                }
                case PDI_END_OF_PACKET: {
                    /*!!!! END OF PACKET !!!!*/
                    if( chksum == 0 ) {
                        [self processPDIPacket:&RxPacket[0] length:RxIndex-1];
                    } else {
                        /*---- checksum error! ----*/
                        
                        // *** This happens when partial packets get
                        //  interspersed with our actual packet data if we are
                        //  trying to send data from the SP-10BN Module faster
                        //  than the iOS frameworks allow
                        self.checkSumErrorCount = self.checkSumErrorCount + 1;
                        LogError(@"Checksum error for packet!  %i.  %i checksum errors", chksum, self.checkSumErrorCount);
                        if ( self.logPackets ) {
                            [[SSPacketLogger packetLogger] logPacket:[NSString stringWithFormat:@"\nChecksum error!  %i.  %i checksum errors.\n", chksum, self.checkSumErrorCount]];
                        }
                    }
                    RxState = RXSTATE_IDLE;
                    RxIndex = 0;
                    return;
                }
                default: {
                    RxPacket[RxIndex] = c;
                    chksum += c;
                    RxIndex++;
                    break;
                }
            }
            break;
        }
            
    }
    
    /*---- check for buffer overrun ----*/
    if( RxIndex >= RXPKTSIZE ) {
        NSData *bytesData = [NSData dataWithBytes:&RxPacket[0] length:RxIndex-1];
        LogError(@"** No Packet found for maximum buffer length.  Byte Data: %@  Parse State: %i.  Character: %x",
                   bytesData, (int)RxState, c);
        if ( self.logPackets ) {
            [[SSPacketLogger packetLogger] logPacket:[NSString stringWithFormat:@"\nNo Packet found for maximum buffer length!  Byte Data: %@  Parse State: %i.  Character: %x", bytesData, (int)RxState, c]];
        }
        RxState = RXSTATE_IDLE;
        RxIndex = 0;
    }
}

-(void) processPDIPacket:(Byte*)bytes length:(int)length {
    @try {
        // for debugging
        if ( self.logPackets ) {
            NSData *bytesData = [NSData dataWithBytes:bytes length:length];
            //Log(@"** Received Packet:\n%@.  size: %i", bytesData, length);
            [[SSPacketLogger packetLogger] logPacket:[NSString stringWithFormat:@"** PACKET: %@\n", bytesData]];
        }
        
        Byte cmd = bytes[0];
        switch (cmd ) {
            case PDI_CMD_VERSION: {
                // call our method to parse the version packet
                [self processFirmwareVersionPacket:bytes length:length];
                break;
            }
            case PDI_CMD_TEMPERATURE: {
                Log(@"Received Temperature.");
                break;
            }
            case PDI_CMD_PRESSURE: {
                Log(@"Received Pressure.");
                break;
            }
            case PDI_CMD_RTC: {
                [self processSystemTimePacket:bytes length:length];
                break;
            }
            case PDI_CMD_CONFIG: {
                Log(@"Received Config.");
                CONFIG_STRUCT cfg;
                int structSize = sizeof(cfg);
                if ( length > structSize ) {
                    memcpy(&cfg, bytes+1, sizeof(cfg));
                    
                    Log(@"* Configuration: Options: %x and %x. BD_ADDR: %x.  Debug Enabled: %x.",
                               cfg.Options[0], cfg.Options[1], cfg.bd_addr, cfg.DebugEnable);
                    
                    if ( self.delegate ) {
                        
                    }
                }
                break;
            }
            case PDI_CMD_LOGGETCONFIG: {
                Log(@"Received LOG GET Config.");
                break;
            }
            case PDI_CMD_LOGCONFIG: {
                Log(@"Received Log Config.");
                
                break;
            }
            case PDI_CMD_LOGRECORD: {
                Log(@"Received Log Record.");
                LOGRECORD_STRUCT record;
                int structSize = sizeof(record);
                if ( length > structSize ) {
                    memcpy(&record, bytes+1, sizeof(record));
                    
                    if ( self.delegate ) {
                        
                    }
                }
                break;
            }
            case PDI_CMD_LOGSTATUS: {
                Log(@"Received Log Status.");
                LOGSTATUS_STRUCT status;
                int structSize = sizeof(status);
                if ( length > structSize ) {
                    memcpy(&status, bytes+1, sizeof(status));
                    
                    if ( self.delegate ) {
                        
                    }
                }
                break;
            }
            case PDI_CMD_STATUS: {
                // call our method to parse the status packet
                [self processStatusPacket:bytes length:length];
                break;
            }
            case PDI_CMD_STREAMRECORD: {
                // call our method to parse a data stream packet
                [self processDataStreamPacket:bytes length:length];
                break;
            }
            default: {
                NSData *bytesData = [NSData dataWithBytes:bytes length:length];
                Log(@"Received Unknown Packet: %x of length: %i. Data: %@", cmd, length, bytesData);
                break;
            }
        }
    }
    @catch (NSException *exception) {
        LogError(@"Error trying to process PDI Packet. %@", exception.description);
    }
}

#pragma mark - Specific Command Packet Parsing

// process / parse a firmware version packet
- (void) processFirmwareVersionPacket:(Byte*)bytes length:(int)length {
    VERSION_STRUCT version;
    int structSize = sizeof(version);
    if ( length > structSize ) {
        memcpy(&version, bytes+1, sizeof(version));
        
        NSString *firmwareVersion = [NSString stringWithFormat:@"%i.%i.%i %i/%i/%i",
                                     version.version, version.revision, version.subrevision,
                                     version.month, version.day, version.year];
        Log(@"Received Version: %@", firmwareVersion);
        
        if ( self.delegate ) {
            [self.delegate onFirmwareVersionParsed:firmwareVersion];
        }
    }
}

// process / parse a system time packet
- (void) processSystemTimePacket:(Byte*)bytes length:(int)length {
    SYSTEM_RTC_STRUCT time;
    int structSize = sizeof(time);
    if ( length > structSize ) {
        memcpy(&time, bytes+1, sizeof(time));
        
        NSString *systemTime = [NSString stringWithFormat:@"%i/%i/%i %i:%i:%i",
                                     time.month, time.day, time.year,
                                     time.hour, time.minute, time.second];
        Log(@"Received System Time: %@", systemTime);
    }
}

// process / parse a status packet
- (void) processStatusPacket:(Byte*)bytes length:(int)length {
    // copy the bytes into our structure
    STATUS_STRUCT status;
    int structSize = sizeof(status);
    if ( length > structSize ) {
        memcpy(&status, bytes+1, sizeof(status));
        
        // let's get the battery volts from the 2 bytes
        Byte v1 = status.DCIN_ADC[0];
        Byte v2 = status.DCIN_ADC[1];
        SInt16 packedVolts = [self wordFromBytes:v1 highByte:v2];
        float volts = (float)packedVolts / 100.f;
        
        if ( self.delegate ) {
            [self.delegate onSensorStatusParsed:status.Model chargerState:status.ChargerState batteryVolts:volts];
        }
    }
}

// process / parse a data stream packet
- (void) processDataStreamPacket:(Byte*)bytes length:(int)length {
    // make sure we check our firmware version
    if ( !_checkedFirmwareVersionForStreamOptions ) {
        [self checkFirmwareVersionForStreamOptions];
    }
    
    // copy this packet into our sensor data struct
    SENSORDATA_STRUCT data;
    int structSize = sizeof(data);
    memset(&data, 0, structSize);
    int lengthToCopy = structSize;
    if ( length <= structSize )
        lengthToCopy = length - 1;
    
    memcpy(&data, bytes+1, lengthToCopy);
    
    // determine our data stream options
    Byte lowOptionsByte = data.options[0];
    Byte highOptionsByte = data.options[1];
    
    // options are little endian - low byte is first - so we need to swap them
    UInt16 options = lowOptionsByte | highOptionsByte << 8;
    
    // create our sensor data object that we will populate with
    // the data included in this packet
    SensorData *sensorData = [[SensorData alloc] init];
    sensorData.options = options;
    
    // iterate through each bit of data included based on the options
    int curByteIndex = 0;
    if ( options & LOGDATA_TIMEDATE ) {
        // 6 Bytes of date/time data
        Byte sec = data.data[curByteIndex++];
        Byte min = data.data[curByteIndex++];
        Byte hour = data.data[curByteIndex++];
        Byte day = data.data[curByteIndex++];
        Byte month = data.data[curByteIndex++];
        Byte year = data.data[curByteIndex++];
        
        sensorData.dateTime = [NSString stringWithFormat:@"%02i/%02i/%04i : %02i:%02i:%02i",
                               month, day, year, hour, min, sec];
    }
    
    if ( options & LOGDATA_TIMESTAMP ) {
        
        // 4 Bytes for the timestamp
        NSData *rawDataForTimestamp = [NSData dataWithBytes:&data.data[curByteIndex] length:sizeof(SInt32)];
        curByteIndex+=4;
        SInt32 siVal;
        size_t siSize = sizeof(SInt32);
        [rawDataForTimestamp getBytes:&siVal length:siSize];
        sensorData.timestamp = siVal;
        
    }
    
    if ( options & LOGDATA_BATTERYVOLTS ) {
        // 1 Byte
        Byte packedVoltsValue = data.data[curByteIndex++];
        float volts = (float)packedVoltsValue / 10.f;
        
        // the battery volts are reported as voltage * 10, so let's divide by 10 to get the actual volts
        sensorData.batteryVolts = volts;
    }
    
    if ( options & LOGDATA_BLESTATE ) {
        // 1 Byte
        Byte bleState = data.data[curByteIndex++];
        sensorData.bleState = bleState;
    }
    
    if ( options & LOGDATA_GYROS ) {
        
        // for the first firmware versions, we used 2 bytes for each gyro reading,
        // but since 0.1.9, we use 4
        if ( _use12BytesForAccelsAndGyros ) {
            // let's get the gyro data (4 bytes each : Q16 values)
            sensorData.gyroscopeX = [self q16FloatFromBytes:&data.data[curByteIndex]];
            curByteIndex += 4;
            
            sensorData.gyroscopeY = [self q16FloatFromBytes:&data.data[curByteIndex]];
            curByteIndex += 4;
            
            sensorData.gyroscopeZ = [self q16FloatFromBytes:&data.data[curByteIndex]];
            curByteIndex += 4;
        } else {
            // let's get the gyro data (
            Byte lowByte = data.data[curByteIndex++];
            Byte highByte = data.data[curByteIndex++];
            SInt16 gyroX = [self wordFromBytes:lowByte highByte:highByte];
            // we scale the raw data appropriately
            sensorData.gyroscopeX = [self scaledGyroscopeData16:gyroX];
            
            lowByte = data.data[curByteIndex++];
            highByte = data.data[curByteIndex++];
            SInt16 gyroY = [self wordFromBytes:lowByte highByte:highByte];
            // we scale the raw data appropriately
            sensorData.gyroscopeY = [self scaledGyroscopeData16:gyroY];
            
            lowByte = data.data[curByteIndex++];
            highByte = data.data[curByteIndex++];
            SInt16 gyroZ = [self wordFromBytes:lowByte highByte:highByte];
            // we scale the raw data appropriately
            sensorData.gyroscopeZ = [self scaledGyroscopeData16:gyroZ];
        }
    }
    
    if ( options & LOGDATA_ACCELS ) {
        // for the first firmware versions, we used 2 bytes for each accel reading,
        // but since 0.1.9, we use 4
        if ( _use12BytesForAccelsAndGyros ) {
            // let's get the accel data (4 bytes each : Q16 values)
            sensorData.accelerometerX = [self q16FloatFromBytes:&data.data[curByteIndex]];
            curByteIndex += 4;
            
            sensorData.accelerometerY = [self q16FloatFromBytes:&data.data[curByteIndex]];
            curByteIndex += 4;
            
            sensorData.accelerometerZ = [self q16FloatFromBytes:&data.data[curByteIndex]];
            curByteIndex += 4;
        } else {
            // let's get the accel data (
            Byte lowByte = data.data[curByteIndex++];
            Byte highByte = data.data[curByteIndex++];
            SInt16 accelX = [self wordFromBytes:lowByte highByte:highByte];
            
            // we scale the raw data appropriately
            sensorData.accelerometerX = [self scaledAccelerometerData16:accelX];
            
            lowByte = data.data[curByteIndex++];
            highByte = data.data[curByteIndex++];
            SInt16 accelY = [self wordFromBytes:lowByte highByte:highByte];
            sensorData.accelerometerY = [self scaledAccelerometerData16:accelY];
            
            lowByte = data.data[curByteIndex++];
            highByte = data.data[curByteIndex++];
            SInt16 accelZ = [self wordFromBytes:lowByte highByte:highByte];
            sensorData.accelerometerZ = [self scaledAccelerometerData16:accelZ];
        }
    }
    
    if ( options & LOGDATA_QUATERNION ) {
        // extract our 4 float quaternion values (Q30 values)
        sensorData.quaternionW = [self q30FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
        
        sensorData.quaternionX = [self q30FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
        
        sensorData.quaternionY = [self q30FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
        
        sensorData.quaternionZ = [self q30FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
    }
    
    if ( options & LOGDATA_COMPASS ) {
        // 6 Bytes of magnetometer data
        Byte lowByte = data.data[curByteIndex++];
        Byte highByte = data.data[curByteIndex++];
        SInt16 x = [self wordFromBytes:lowByte highByte:highByte];
        sensorData.magnetometerX = x;
        
        lowByte = data.data[curByteIndex++];
        highByte = data.data[curByteIndex++];
        SInt16 y = [self wordFromBytes:lowByte highByte:highByte];
        sensorData.magnetometerY = y;
        
        lowByte = data.data[curByteIndex++];
        highByte = data.data[curByteIndex++];
        SInt16 z = [self wordFromBytes:lowByte highByte:highByte];
        sensorData.magnetometerZ = z;
    }
    
    if ( options & LOGDATA_PRESSURE ) {
        // 4 Bytes of pressure data
        Byte lowByte = data.data[curByteIndex++];
        Byte lowByte2 = data.data[curByteIndex++];
        Byte highByte = data.data[curByteIndex++];
        Byte highByte2 = data.data[curByteIndex++];
        SInt32 v = [self dwordFromBytes:lowByte lowByte2:lowByte2 highByte:highByte highByte2:highByte2];
        sensorData.pressure = v;
    }
    
    if ( options & LOGDATA_TEMPERATURE ) {
        // 2 Bytes of temperature data
        Byte lowByte = data.data[curByteIndex++];
        Byte highByte = data.data[curByteIndex++];
        SInt16 packedTemp = [self wordFromBytes:lowByte highByte:highByte];
        
        // the temperature is reported as celsius * 10, so lets convert
        float temperatureInCelsius = (float)packedTemp / 10.f;
        sensorData.temperatureInCelsius = temperatureInCelsius;
    }
    
    if ( options & LOGDATA_LINEARACCEL ) {
        
        if ( _use12BytesForAccelsAndGyros ) {
            // 12 Bytes of linear acceleration data - 3 Q16 float values
            sensorData.linearAccelerationX = [self q16FloatFromBytes:&data.data[curByteIndex]];
            curByteIndex += 4;
            
            sensorData.linearAccelerationY = [self q16FloatFromBytes:&data.data[curByteIndex]];
            curByteIndex += 4;
            
            sensorData.linearAccelerationZ = [self q16FloatFromBytes:&data.data[curByteIndex]];
            curByteIndex += 4;
            
        } else {
            // 6 Bytes of linear acceleration data
            Byte lowByte = data.data[curByteIndex++];
            Byte highByte = data.data[curByteIndex++];
            SInt16 x = [self wordFromBytes:lowByte highByte:highByte];
            sensorData.linearAccelerationX = x;
            
            lowByte = data.data[curByteIndex++];
            highByte = data.data[curByteIndex++];
            SInt16 y = [self wordFromBytes:lowByte highByte:highByte];
            sensorData.linearAccelerationY = y;
            
            lowByte = data.data[curByteIndex++];
            highByte = data.data[curByteIndex++];
            SInt16 z = [self wordFromBytes:lowByte highByte:highByte];
            sensorData.linearAccelerationZ = z;
        }
    }
    
    if ( options & LOGDATA_EULER ) {
        // 12 bytes of Euler Angles (3 Q16 Float values)
        sensorData.eulerX = [self q16FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
        
        sensorData.eulerY = [self q16FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
        
        sensorData.eulerZ = [self q16FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
    }
    if ( options & LOGDATA_RSSI ) {
        // 2 Bytes of BLE RSSI data
        Byte lowByte = data.data[curByteIndex++];
        Byte highByte = data.data[curByteIndex++];
        SInt16 rssi = [self wordFromBytes:lowByte highByte:highByte];
        sensorData.bleRSSI = rssi;
    }
    
    if ( options & LOGDATA_ROTMATRIX ) {
        // 36 bytes - 9 Q30 Float values
        sensorData.rotationMatrixA = [self q30FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
        
        sensorData.rotationMatrixB = [self q30FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
        
        sensorData.rotationMatrixC = [self q30FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
        
        sensorData.rotationMatrixD = [self q30FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
        
        sensorData.rotationMatrixE = [self q30FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
        
        sensorData.rotationMatrixF = [self q30FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
        
        sensorData.rotationMatrixG = [self q30FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
        
        sensorData.rotationMatrixH = [self q30FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
        
        sensorData.rotationMatrixI = [self q30FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
    }
    
    if ( options & LOGDATA_HEADING ) {
        // 4 bytes - q16 float value
        sensorData.heading = [self q16FloatFromBytes:&data.data[curByteIndex]];
        curByteIndex += 4;
    }
    
    // let our delegate know that we have sensor data
    if ( self.delegate ) {
        [self.delegate onSensorDataParsed:sensorData];
    }
}

#pragma mark - Value Extraction

// extract a Q16 float from the given bytes
- (Float32) q16FloatFromBytes:(Byte*)bytes {
 
    // extract our bytes
    Byte lowByte = bytes[0];
    Byte midLowByte = bytes[1];
    Byte midHighByte = bytes[2];
    Byte highByte = bytes[3];
    
    // get the raw packed DWORD value
    SInt32 siVal = [self dwordFromBytes:lowByte lowByte2:midLowByte highByte:midHighByte highByte2:highByte];
    
    // extract & return the Q16 value
    return [self q16Value:siVal];
}

// extract a Q30 float from the given bytes
- (Float32) q30FloatFromBytes:(Byte*)bytes {
    
    // extract our bytes
    Byte lowByte = bytes[0];
    Byte midLowByte = bytes[1];
    Byte midHighByte = bytes[2];
    Byte highByte = bytes[3];
    
    // get the raw packed DWORD value
    SInt32 siVal = [self dwordFromBytes:lowByte lowByte2:midLowByte highByte:midHighByte highByte2:highByte];
    
    // extract & return the Q30 value
    return [self q30Value:siVal];
}

// get the SInt16 WORD value for the given 2 bytes
- (SInt16) wordFromBytes:(Byte)lowByte highByte:(Byte)highByte {
    return (SInt16)lowByte | (SInt16)((SInt16)highByte << 8);
}

// get the SInt32 DWORD valuye for the given 4 bytes
- (SInt32) dwordFromBytes:(Byte)lowByte lowByte2:(Byte)lowByte2 highByte:(Byte)highByte highByte2:(Byte)highByte2 {
    return (SInt32)lowByte | (SInt32)((SInt32)lowByte2 << 8) | (SInt32)((SInt32)highByte << 16) | (SInt32)((SInt32)highByte2 << 24);
}

// get a fixed point Q16 value from a raw integer
- (float) q16Value:(SInt32) rawVal {
    // these are fixed point Q16 numbers so we divide by 2^16 (65,536)
    return (float)rawVal / (float)65536;
}

// get a fixed point Q30 value from a raw integer
- (float) q30Value:(SInt32) rawVal {
    // these are fixed point Q30 numbers so we divide by 2^30 (1073741824)
    return (float)rawVal / (float)1073741824;
}

- (float) scaledAccelerometerData16:(SInt16) rawAccelVal {
    // the accelerometer data is a full scale of 2G so let's adjust this accordingly
    //INT16_MAX = 2G;
    //INT16_MIN = -2G;
    //
    // so let's figure where we are in the scale
    if ( rawAccelVal > 0 ) {
        return ((float)(rawAccelVal / (float)INT16_MAX)) * 2.f;
    } else {
        return ((float)(rawAccelVal / (float)INT16_MIN)) * -2.f;
    }
}

- (float) scaledGyroscopeData16:(SInt16) rawVal {
    // the gyroscope data is a full scale of 2000 degrees per second so let's adjust this accordingly
    //INT16_MAX = 2,000 dps;
    //INT16_MIN = -2,000 dps;
    //
    // so let's figure where we are in the scale
    if ( rawVal > 0 ) {
        return ((float)(rawVal / (float)INT16_MAX)) * 2000.f;
    } else {
        return ((float)(rawVal / (float)INT16_MIN)) * -2000.f;
    }
}

#pragma mark - Firmware Version Check

// determine the different options for our data stream based on
// the firmware version being parsed
- (void) checkFirmwareVersionForStreamOptions {
    if ( self.firmwareVersion.length ) {
        // get the major, minor and build values
        NSArray *mainComponents = [self.firmwareVersion componentsSeparatedByString:@" "];
        NSString *fwVersionOnly = nil;
        if ( mainComponents.count > 0 )
            fwVersionOnly = [mainComponents objectAtIndex:0];
        NSArray *components = [fwVersionOnly componentsSeparatedByString:@"."];
        NSString *major = nil, *minor = nil, *build = nil;
        if ( components.count > 0 )
            major = [components objectAtIndex:0];
        if ( components.count > 1 )
            minor = [components objectAtIndex:1];
        if ( components.count > 2 )
            build = [components objectAtIndex:2];
        
        // get the int values
        //int nMajor = [major intValue];
        //int nMinor = [minor intValue];
        int nBuild = -1;
        if ( build.length )
            nBuild = [build intValue];
        
        if ( nBuild > 8 ) {
            _use12BytesForAccelsAndGyros = YES;
        } else if ( nBuild > -1 ) {
            _use12BytesForAccelsAndGyros = NO;
        }
        
        _checkedFirmwareVersionForStreamOptions = YES;
    }
}


@end
