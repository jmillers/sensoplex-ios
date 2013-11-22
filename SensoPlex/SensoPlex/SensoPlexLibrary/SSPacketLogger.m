//
//  SSPacketLogger.m
// 
//
//  Created by Jeremy Millers on 9/6/13.
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

#import "SSPacketLogger.h"

// This is a singleton class, see below
static SSPacketLogger* sharedPacketLogger = nil;

@interface SSPacketLogger ()

@property (strong, atomic, retain) NSRecursiveLock *packetLock;

@end


@implementation SSPacketLogger

+(SSPacketLogger *) packetLogger {
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        sharedPacketLogger = [[SSPacketLogger alloc] init];
    });
    return sharedPacketLogger;
}

- (id) init {
    if ( self = [super init] ) {
        self.packetLock = [[NSRecursiveLock alloc] init];
    }
    
    return self;
}

// return the maximum file size before having to clear the log file
- (SInt32) maxFileSize {
    return 0;
}

// get the log file's filename/path
- (NSString*) logFileLocation {
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"packets.rtf"];
    return fileName;
}

- (void) logPacket:(NSString *)packet {
    BOOL locked = NO;
    @try {
        // open the file handle if needed (if this is our first)
        [self openLogFileIfNeeded];
        
        [self.packetLock lock];
        locked = YES;
        
        // append text to file (add a newline every write)
        NSString *contentToWrite = [NSString stringWithFormat:@"%@\n",
                                    packet];
        [fileHandle writeData:[contentToWrite dataUsingEncoding:NSUTF8StringEncoding]];
    }
    @catch (NSException *exception) {
        
    } @finally {
        if ( locked ) {
            [self.packetLock unlock];
        }
    }
}


@end
