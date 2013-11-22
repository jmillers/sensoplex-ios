//
//  SensoPlex.h
// 
//
//  Created by Jeremy Millers on 7/16/13.
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

#ifndef Sweet_Pro_SensoPlex_h
#define Sweet_Pro_SensoPlex_h

// the BLE Service UUID that we use to send and receive data with the SP-10BN Module
#define BLE_TRANSFER_SERVICE_UUID       @"01000000-0000-0000-0000-000000000080"

// the BLE Characteristic UUID that we actually write to for the service in
// order to send data to the SP-10BN Module
#define BLE_WRITE_CHARACTERISTIC_UUID   @"04000000-0000-0000-0000-000000000080"

// the BLE Characteristic UUID for the Characteristic that we receive notifications
// on when the SP-10BN Module sends data up to us
#define BLE_NOTIFY_CHARACTERISTIC_UUID      @"02000000-0000-0000-0000-000000000080"

// BLE Characteristic UUID for the characteristic that supports BLE indications
// (not currently used for any communication)
#define BLE_INDICATE_CHARACTERISTIC_UUID    @"03000000-0000-0000-0000-000000000080"


/*---- Status Commands ----*/
#define BLE_CMD_STATUS 0x30 
#define BLE_CMD_VERSION 0x34 
#define BLE_CMD_GETCONFIG 0x35 

/*---- Data Logging Commands ----*/
#define BLE_CMD_LOGGETSTATUS 0x58 
#define BLE_CMD_LOGCLEAR 0x59 
#define BLE_CMD_LOGFIRSTGETRECORD 0x5a
#define BLE_CMD_LOGGETRECORD 0x5b  // 2nd byte: record num (256 byte), modulo 256
#define BLE_CMD_LOGGETCONFIG 0x5c
#define BLE_CMD_LOGENABLE 0x5e  // 2nd byte: 0=disable, 1=enable

/*---- Misc Commands ----*/
#define BLE_CMD_SETLED 0x80 // 2nd byte: bit0=Green, bit1=Red, bit7=1 to restore internal LED control
#define BLE_CMD_LEDGREEN 0x01
#define BLE_CMD_LEDRED 0x02
#define BLE_CMD_LEDSYSCONTROL 0x80

#define BLE_CMD_SETRTC 0x82 // 2nd byte: TBD
#define BLE_CMD_GETRTC 0x83
#define BLE_CMD_GET_PRESSURE 0x86
#define BLE_CMD_GET_TEMPERATURE 0x87


/*---- Status Commands ----*/
#define PDI_CMD_STATUS 0x30 
#define PDI_CMD_VERSION 0x34 
#define PDI_CMD_CONFIG 0x35 

/*---- Data Logging Commands ----*/
#define PDI_CMD_LOGSTATUS 0x58 
#define PDI_CMD_LOGRECORD 0x5a 
#define PDI_CMD_LOGCONFIG 0x5b 
#define PDI_CMD_LOGGETCONFIG 0x5c


/*---- Misc Commands ----*/
#define PDI_CMD_RTC 0x83 
#define PDI_CMD_PRESSURE 0x86 
#define PDI_CMD_TEMPERATURE 0x87


/*---- Packet Interface ----*/
#define PDI_START_OF_PACKET 0xD1
#define PDI_END_OF_PACKET   0xDF
#define PDI_BYTE_STUFFING   0xDE

/*---- Data Streaming Commands ----*/
#define     BLE_CMD_STREAMGETCONFIG       0x61
#define     BLE_CMD_STREAMSETCONFIG       0x62
#define     BLE_CMD_STREAMENABLE          0x63

/*---- Data Streaming Commands ----*/
#define	PDI_CMD_STREAMRECORD		0x60
#define	PDI_CMD_STREAMGETCONFIG		0x61
#define	PDI_CMD_STREAMSETCONFIG		0x62
#define	PDI_CMD_STREAMENABLE		0x63

enum ERROR_TYPES {
    ERROR_UART_TXOVERFLOW,        // 0
    ERROR_UART_RXBUFFERFULL,      // 1
    ERROR_UART_RXCIRBUFFERFULL,   // 2
    ERROR_UART_PARITYOVERFLOW,    // 3
    ERROR_BLE_TXOVERFLOW,         // 4
    ERROR_BLE_RXBUFFERFULL,       // 5
    ERROR_BLE_STACK,              // 6
    ERROR_NVM,                    // 7
    ERROR_SPI,                    // 8
    ERROR_PRESSURE,               // 9
    ERROR_MPL,                    // 10
    ERROR_FLASH,                  // 11
    ERROR_NUMOFTYPES
};

typedef struct {
    Byte Model;
    Byte ChargerState;
    Byte DCIN_ADC[2];
    unsigned char Error[ERROR_NUMOFTYPES];
} STATUS_STRUCT;

typedef struct {
    Byte version;
    Byte revision;
    Byte subrevision;
    Byte month;
    Byte day;
    Byte year;
    Byte model; // STANDARD, PROD. TEST, ENG. TEST, or CUSTOM
} VERSION_STRUCT;

typedef struct {
    Byte month;
    Byte day;
    Byte year;
    Byte hour;
    Byte minute;
    Byte second;
    Byte extra;
} SYSTEM_RTC_STRUCT;

typedef struct {
    //---- Bluetooth board address ----
    Byte bd_addr[6];
    // ---- programmable configuration ----
    Byte DebugEnable; // Bits for enabling debug modes
    Byte unused; // (padding)
    // --- configurable enable/disables ----
    Byte Options[2]; // Configurable options (TBD)
} CONFIG_STRUCT;

typedef struct {
    Byte Enabled;
    Byte dummy; // (spare)
    Byte Log_NumOfRecords[2];
    Byte Log_UsedBytes[4];
    Byte Log_TotalBytes[4];
} LOGSTATUS_STRUCT;

typedef struct {
    Byte Length; // length of record (not including length byte) BYTE Id;
    Byte Sensors[2];
    Byte Data[100];
} LOGRECORD_STRUCT;

typedef struct {
    Byte Enabled;
    Byte dummy; // (spare)
    Byte Sensors[2];
    int Interval;
} LOGTYPE_STRUCT;

typedef struct {
    /*---- logging configuration ----*/
    LOGTYPE_STRUCT type[3]; // define 3 types of logging record types
} LOGCONFIG_STRUCT;


// struct for the streaming data that gets sent up
typedef struct {
    Byte options[2];
    Byte data[129];
    
} SENSORDATA_STRUCT;

// constants for the sensor data options
#define     LOGDATA_TIMEDATE        0x0001            // 1
#define     LOGDATA_TIMESTAMP       0x0002            // 2
#define     LOGDATA_BATTERYVOLTS    0x0004            // 3
#define     LOGDATA_BLESTATE        0x0008            // 4
#define     LOGDATA_GYROS           0x0010            // 5
#define     LOGDATA_ACCELS          0x0020            // 6
#define     LOGDATA_QUATERNION      0x0040            // 7
#define     LOGDATA_COMPASS         0x0080            // 8
#define     LOGDATA_PRESSURE        0x0100            // 9
#define     LOGDATA_TEMPERATURE     0x0200            // 10
#define     LOGDATA_LINEARACCEL     0x0400            // 11
#define     LOGDATA_EULER           0x0800            // 12
#define     LOGDATA_RSSI            0x1000            // 13
#define     LOGDATA_ROTMATRIX       0x2000            // 14
#define     LOGDATA_HEADING         0x4000            // 15


#endif
