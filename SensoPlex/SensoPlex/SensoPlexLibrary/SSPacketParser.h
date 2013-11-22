//
//  SSPacketParser.h
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

#import <Foundation/Foundation.h>

@class SensorData;

@protocol SSPacketParserDelegate <NSObject>

- (void) onFirmwareVersionParsed:(NSString*)fwVersion;
- (void) onSensorDataParsed:(SensorData *)data;
- (void) onSensorStatusParsed:(Byte)sensorModel chargerState:(Byte)chargerState
                 batteryVolts:(float)batteryVolts;

@end

@interface SSPacketParser : NSObject

@property (weak, nonatomic) NSObject<SSPacketParserDelegate> *delegate;
@property (assign) BOOL logPackets;
@property (assign) int checkSumErrorCount;

// the firmware version
@property (strong, nonatomic) NSString *firmwareVersion;

-(void) processPacketByte:(Byte) c;
-(void) processPDIPacket:(Byte*)bytes length:(int)length;

@end
