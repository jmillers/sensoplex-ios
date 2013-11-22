//
//  SensorData.h
// 
//
//  Created by Jeremy Millers on 8/1/13.
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

#import <Foundation/Foundation.h>

@interface SensorData : NSObject {
    
}

// the options that define what is included in this sensor data
// (the bitmasks for this are defined in SensoPlex-Constants.h)
// this is the raw options value (with endianess correction) that
// the SP-10BN Module gives to us
@property (nonatomic, assign) UInt16 options;

// date time information (month/day/year : hour:min:sec)
@property (nonatomic, retain) NSString *dateTime;

// timestamp (milliseconds)
@property (nonatomic, assign) SInt32 timestamp;

// accelerometer data (G's)
@property (nonatomic, assign) float accelerometerX;
@property (nonatomic, assign) float accelerometerY;
@property (nonatomic, assign) float accelerometerZ;

// gyrosope data (degrees per second)
@property (nonatomic, assign) float gyroscopeX;
@property (nonatomic, assign) float gyroscopeY;
@property (nonatomic, assign) float gyroscopeZ;

// quaternions
@property (nonatomic, assign) float quaternionW;
@property (nonatomic, assign) float quaternionX;
@property (nonatomic, assign) float quaternionY;
@property (nonatomic, assign) float quaternionZ;

// temperature
@property (nonatomic, assign) float temperatureInCelsius;

// compass
@property (nonatomic, assign) float magnetometerX;
@property (nonatomic, assign) float magnetometerY;
@property (nonatomic, assign) float magnetometerZ;

// battery voltage
@property (nonatomic, assign) float batteryVolts;

// linear acceleration data
@property (nonatomic, assign) float linearAccelerationX;
@property (nonatomic, assign) float linearAccelerationY;
@property (nonatomic, assign) float linearAccelerationZ;

// euler angles
@property (nonatomic, assign) float eulerX;
@property (nonatomic, assign) float eulerY;
@property (nonatomic, assign) float eulerZ;

// rotation matrix
@property (nonatomic, assign) float rotationMatrixA;
@property (nonatomic, assign) float rotationMatrixB;
@property (nonatomic, assign) float rotationMatrixC;
@property (nonatomic, assign) float rotationMatrixD;
@property (nonatomic, assign) float rotationMatrixE;
@property (nonatomic, assign) float rotationMatrixF;
@property (nonatomic, assign) float rotationMatrixG;
@property (nonatomic, assign) float rotationMatrixH;
@property (nonatomic, assign) float rotationMatrixI;

// heading
@property (nonatomic, assign) float heading;

// pressure
@property (nonatomic, assign) SInt32 pressure;

// BLE information
@property (nonatomic, assign) Byte bleState;
@property (nonatomic, assign) Byte bleRSSI;


@end
