//
//  MoLogger.m
//
//  Created by Jeremy Millers on 07/17/13.
//  Copyright (c) 2013 moBiddy, Inc. All rights reserved.
//

#import "MoLogger.h"
#import "MoConstants.h"

// max file size before clipping
#define MAX_LOG_FILE_SIZE 1024000

// This is a singleton class, see below
static MoLogger* sharedLogger = nil;

// we cache whether we should log all messages or just errors
static BOOL enableMessageLogging = YES;

@interface MoLogger()

@property (strong, nonatomic, retain) NSRecursiveLock *lock;

@end

#pragma mark -
#pragma mark Logging

// option to redefine error logging
void LogError ( NSString *format, ... )
{
    @try {
        va_list args;
        va_start(args, format);
        NSString *formattedContent = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        
        [MoLogger logError:formattedContent];
    
        NSLog(@"%@", formattedContent);
    }
    @catch (NSException *exception) {
        NSLog(@"*** ERROR trying to log error: %@", exception.description);
    }
}

// option to redefine message logging
void Log ( NSString *format, ... ) {

    @try {
        va_list args;
        va_start(args, format);
        
        NSString *formattedContent = [[NSString alloc] initWithFormat:format arguments:args];
        [MoLogger log:formattedContent];
        
#ifdef _LOG_TO_CONSOLE
        if ( formattedContent )
            NSLog(@"%@", formattedContent);
#endif
        
        va_end(args);
    }
    @catch (NSException *exception) {
        NSLog(@"*** ERROR trying to log message: %@", exception.description);
    }
}

@implementation MoLogger

@synthesize fileHandle;
@synthesize dateFormatter;

- (id) init {
    if ( self = [super init] ) {
        self.lock = [[NSRecursiveLock alloc] init];
    }
    
    return self;
}

+ (void) logError:(NSString *) error {
    MoLogger *logger = [MoLogger logger];
    @try {
        // prepend error and log the content
        NSString *content = [NSString stringWithFormat: @"ERROR: %@", error];
        [logger log:content];
    } @catch (NSException *exception) {
        NSLog(@"Error trying to LogMessage for MoLogger  %@", exception);
    }
}

+ (void) log:(NSString *) msg  {
    MoLogger *logger = [MoLogger logger];
    @try {
        if ( enableMessageLogging ) {
            
            // log the content
            NSString *content = msg; //[[NSString alloc] initWithFormat:format arguments:args];
            //NSString *content = [NSString stringWithFormat:format, args];
            [logger log:content];
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Error trying to LogMessage for MoLogger  %@", exception);
    }
}

-(void) log:(NSString*)content {

    BOOL locked = NO;
    @try {
        
        [self.lock lock];
        locked = YES;

        // open the file handle if needed (if this is our first)
        [self openLogFileIfNeeded];
        
        // prepend the date/time and append a newline
        if ( !dateFormatter ) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss:SSS";
            self.dateFormatter = formatter;
        }
        
        //append text to file (you'll probably want to add a newline every write)
        NSDate *date = [NSDate date];
        NSString *timestamp = [dateFormatter stringFromDate:date];
        NSString *contentToWrite = [NSString stringWithFormat:@"%@ %@\n",
                                    timestamp, content];
        [fileHandle writeData:[contentToWrite dataUsingEncoding:NSUTF8StringEncoding]];
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        if ( locked )
            [self.lock unlock];
    }
}

- (void) openLogFileIfNeeded {
    if ( !fileHandle ) {
        
        //Get the file path
        NSString *fileName = [self logFileLocation];
        
        //create file if it doesn't exist
        if(![[NSFileManager defaultManager] fileExistsAtPath:fileName])
            [[NSFileManager defaultManager] createFileAtPath:fileName contents:nil attributes:nil];
        
        //append text to file
        NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:fileName];
        unsigned long long fileSize = [file seekToEndOfFile];
        
        // clear the file if it gets too big
        if ( fileSize > [self maxFileSize] ) {
            [file truncateFileAtOffset:0];
        }
        
        self.fileHandle = file;
        
        [self log:@"\n\n********* NEW LOG INSTANCE **********\n"];
        
        // add the app version to this, as well as other OS information
        UIDevice *device = [UIDevice currentDevice];
        NSString *deviceInfo = [NSString stringWithFormat:@"%@ - OS: %@", device.model, device.systemVersion];
        Log(deviceInfo);
        NSString *appInfo = [NSString stringWithFormat:@"App Version: %@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
        Log(appInfo);
    }
}

// enable / disable logging
- (void) enableLogging:(BOOL)enable {
    enableMessageLogging = enable;
}

// close the log file
- (void) closeLogFile {
    [fileHandle closeFile];
    self.fileHandle = nil;
}

// get the log file's filename/path
- (NSString*) logFileLocation {
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"log.rtf"];
    return fileName;
}

// return the maximum file size before having to clear the log file
- (SInt32) maxFileSize {
    return MAX_LOG_FILE_SIZE;
}

#pragma mark -
#pragma mark Singleton Object Methods

+(MoLogger *)logger {
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        sharedLogger = [[MoLogger alloc] init];
    });
    return sharedLogger;
}



@end
