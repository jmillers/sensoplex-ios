//
//  MoLogger.h
//
//  Created by Jeremy Millers on 4/9/13.
//  Copyright (c) 2013 moBiddy, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef _LOG_ERROR_
#define _LOG_ERROR_

#ifdef __cplusplus
extern "C"
{
#endif
	void LogError(NSString* format, ...);
#ifdef __cplusplus
}
#endif


#endif

#ifndef _LOG_MESSAGE_
#define _LOG_MESSAGE_

#ifdef __cplusplus
extern "C"
{
#endif
	void Log(NSString* format, ...);
#ifdef __cplusplus
}
#endif

#endif

@interface MoLogger : NSObject {

    // the file handle that we write to
    NSFileHandle *fileHandle;
    
    // the date/time formatter for timestamping each log
    NSDateFormatter *dateFormatter;
}

@property (strong, atomic, retain) NSFileHandle *fileHandle;
@property (strong, atomic, retain) NSDateFormatter *dateFormatter;

+ (MoLogger*) logger;

+ (void) logError:(NSString *)error;
+ (void) log:(NSString *)msg;

// close the log file
- (void) closeLogFile;

// get the log file's filename/path
- (NSString*) logFileLocation;

// enable / disable logging
- (void) enableLogging:(BOOL)enable;

// open the log file if we need to (this gets called automatically
// when logging messages or errors
- (void) openLogFileIfNeeded;

// return the maximum file size before having to clear the log file
- (SInt32) maxFileSize;

@end
