//
//  TBInputStream.m
//  TBIPC
//
//  Created by Tanner on 4/10/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import <TBSockets/TBInputStream.h>


@interface TBInputStream () <NSStreamDelegate>
@property (nonatomic, readonly) NSRunLoop *runLoop;
@property (nonatomic, readonly) void(^openCallback)(TBInputStream *);

#pragma mark - Async read jobs
@property (nonatomic) BOOL reading;
@property (nonatomic) NSMutableData *currentReadJob;
@property (nonatomic) NSUInteger currentReadJobToRead;
@property (nonatomic) NSMutableArray<NSNumber*> *pendingReadJobs;
/// First object is that of the current job
@property (nonatomic) NSMutableArray<TBSocketReadCallback> *pendingReadJobCallbacks;
@end

@implementation TBInputStream

#pragma mark - Initialization

+ (instancetype)from:(NSInputStream *)stream {
    TBInputStream *me = [self new];
    me->_stream = stream;
    stream.delegate = me;
    return me;
}

- (id)init {
    self = [super init];
    if (self) {
        self.pendingReadJobs = [NSMutableArray array];
        self.pendingReadJobCallbacks = [NSMutableArray array];
    }

    return self;
}

#pragma mark - Open / Close

- (void)open:(void(^)(TBInputStream *stream))openCallback {
    _runLoop = [NSRunLoop currentRunLoop];
    _openCallback = openCallback;
    [self.stream scheduleInRunLoop:_runLoop forMode:NSDefaultRunLoopMode];
    [self.stream open];
}

- (void)close {
    [self.stream removeFromRunLoop:_runLoop forMode:NSDefaultRunLoopMode];
    [self.stream close];
    _runLoop = nil;
}

#pragma mark - Convenience

- (NSNumber *)read8 {
    return [self readPrimitive:sizeof(UInt8)];
}

- (NSNumber *)read16 {
    return [self readPrimitive:sizeof(UInt16)];
}

- (NSNumber *)read32 {
    return [self readPrimitive:sizeof(UInt32)];
}

- (NSNumber *)read64 {
    return [self readPrimitive:sizeof(UInt64)];
}

#pragma mark - Private

- (NSData *)dataCopyFromBuffer:(void *)buffer length:(NSUInteger)dataLength {
    NSData *data = [NSData dataWithBytes:buffer length:dataLength];
    free(buffer);
    return data;
}

- (void)readForCurrentReadJob {
    if (self.currentReadJob && !self.reading) {
        @synchronized (_stream) {
            self.reading = YES;

            // Read available bytes for current job only
            NSError *error = nil;
            NSUInteger remaining = self.currentReadJobToRead - self.currentReadJob.length;
            NSData *newBytes = [self readMaxLength:remaining error:&error];

            if (!newBytes) {
                // We reached EOF before any data could be read.
                // This shouldn't happen because this is only called
                // when bytes are available.
                @throw NSInternalInconsistencyException;
            }

            // Append read data
            [self.currentReadJob appendData:newBytes];

            // Handle error or move to next job
            if (error) {
                [self finishCurrentReadJobWithError:error];
            } else {
                if (self.currentReadJob.length == self.currentReadJobToRead) {
                    // Current job is complete
                    [self finishCurrentReadJobWithError:nil];
                }
            }

            self.reading = NO;
        }

        // Read for next job
        if (self.stream.hasBytesAvailable) {
            [self readForCurrentReadJob];
        }
    }
}

- (NSNumber *)readPrimitive:(NSUInteger)length {
    void *buffer = alloca(length);

    NSUInteger read = 0;
    while (read < length) {
        NSInteger status = [self.stream read:(buffer + read) maxLength:length - read];

        // Stream error or EOF, cannot continue
        if (status < 1) {
            return nil;
        }

        read += status;
    }

    switch (length) {
        case sizeof(UInt8):
            return @(*(UInt8 *)buffer);
        case sizeof(UInt16):
            return @(NSSwapShort(*(UInt16 *)buffer));
        case sizeof(UInt32):
            return @(NSSwapInt(*(UInt32 *)buffer));
        case sizeof(UInt64):
            return @(NSSwapLong(*(UInt64 *)buffer));

        default:
            @throw NSGenericException;
            return nil;
    }
}

- (NSData *)readMaxLength:(NSUInteger)desired error:(NSError **)error {
    if (!desired) {
        return nil;
    }

    void *buffer = malloc(desired);
    NSInteger status = [self.stream read:buffer maxLength:desired];

    // Stream error or EOF, no data was read
    if (status < 1) {
        // Pass back error if any
        if (status == -1 && error) {
            *error = self.stream.streamError;
        }

        return nil;
    }

    if (status == desired) {
        // All data was read, return it
        return [NSData dataWithBytesNoCopy:buffer length:status];
    } else {
        // Free overallocated buffer and return a copy of the read data
        return [self dataCopyFromBuffer:buffer length:status];
    }
}

- (void)finishCurrentReadJobWithError:(NSError *)error {
    // Execute the callback and discard it
    self.pendingReadJobCallbacks.firstObject(self.currentReadJob, error);
    [self.pendingReadJobCallbacks removeObjectAtIndex:0];

    if (self.pendingReadJobs) {
        // Dequeue the next job
        self.currentReadJob       = [NSMutableData data];
        self.currentReadJobToRead = self.pendingReadJobs.firstObject.integerValue;
        [self.pendingReadJobs removeObjectAtIndex:0];
    } else {
        // No more jobs
        self.currentReadJob       = nil;
        self.currentReadJobToRead = 0;
    }
}

#pragma mark - Sync

- (NSData *)readToLength:(NSUInteger)length error:(NSError **)error {
    void *buffer = malloc(length);

    NSUInteger read = 0;
    while (read < length) {
        NSInteger status = [self.stream read:(buffer + read) maxLength:length - read];

        // Stream error or EOF, cannot continue
        if (status < 1) {
            // Pass back error if any
            if (status < 0 && error) {
                *error = self.stream.streamError;
            }

            if (read) {
                // Free overallocated buffer and return a copy of the read data
                return [self dataCopyFromBuffer:buffer length:read];
            } else {
                free(buffer);
                return nil;
            }
        }

        // Keep reading
        read += status;
    }

    return [NSData dataWithBytesNoCopy:buffer length:length];
}

#pragma mark - Async

- (void)readToLength:(NSUInteger)length completion:(TBSocketReadCallback)callback {
    // Synchronized to protect the thread safety of the current job state
    @synchronized (_stream) {
        [self.pendingReadJobCallbacks addObject:callback];

        if (self.currentReadJob) {
            [self.pendingReadJobs addObject:@(length)];
        } else {
            self.currentReadJob = [NSMutableData data];
            self.currentReadJobToRead = length;

            // Maybe read right now for the job
            if (self.stream.hasBytesAvailable) {
                [self readForCurrentReadJob];
            }
        }
    }
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event {
    switch (event) {
        case NSStreamEventNone:
            break;
        case NSStreamEventOpenCompleted:
            if (self.openCallback) {
                self.openCallback(self);
                _openCallback = nil;
            }
            break;
        case NSStreamEventHasBytesAvailable:
            [self readForCurrentReadJob];
            break;
        case NSStreamEventHasSpaceAvailable:
        case NSStreamEventErrorOccurred:
        case NSStreamEventEndEncountered:
            // All of this is handled as we read and write
            break;
    }
}

@end
