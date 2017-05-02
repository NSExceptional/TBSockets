//
//  TBOutputStream.m
//  TBIPC
//
//  Created by Tanner on 4/10/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import <TBOutputStream.h>


@interface TBOutputStream ()

#pragma mark - Async write jobs
@property (nonatomic) BOOL writing;
@property (nonatomic) NSData *currentWriteJob;
@property (nonatomic) NSUInteger currentWriteJobWritten;
@property (nonatomic) NSMutableArray<NSData*> *pendingWriteJobs;
/// First object is that of the current job
@property (nonatomic) NSMutableArray<TBSocketWriteCallback> *pendingWriteJobCallbacks;
@end

@implementation TBOutputStream
@dynamic stream;

#pragma mark - Initialization

- (id)init {
    self = [super init];
    if (self) {
        self.pendingWriteJobs = [NSMutableArray array];
        self.pendingWriteJobCallbacks = [NSMutableArray array];
    }

    return self;
}

#pragma mark - Private

- (NSUInteger)write:(const void *)data maxLength:(NSUInteger)length error:(NSError **)error {
    if (!data || !length) {
        return 0;
    }

    NSInteger status = [self.stream write:data maxLength:length];

    // Stream error or EOF, no data was written
    if (status < 1) {
        // Pass back error if any
        if (status == -1 && error) {
            *error = self.stream.streamError;
        }

        return 0;
    }

    return status;
}

- (void)writeForCurrentWriteJob {
    if (self.currentWriteJob && !self.writing) {
        @synchronized (self.stream) {
            self.writing = YES;

            // Write data and update index
            NSError *error = nil;
            const void *toWrite = self.currentWriteJob.bytes + self.currentWriteJobWritten;
            NSUInteger length = self.currentWriteJob.length - self.currentWriteJobWritten;
            self.currentWriteJobWritten += [self write:toWrite maxLength:length error:&error];

            // Handle error or move to next job
            if (error) {
                [self finishCurrentWriteJobWithError:error];
            } else {
                if (self.currentWriteJob.length == self.currentWriteJobWritten) {
                    // Current job is complete
                    [self finishCurrentWriteJobWithError:nil];
                }
            }

            self.writing = NO;
        }

        // Write for next job
        if (self.stream.hasSpaceAvailable) {
            [self writeForCurrentWriteJob];
        }
    }
}

- (void)finishCurrentWriteJobWithError:(NSError *)error {
    // Execute the callback and discard it
    self.pendingWriteJobCallbacks.firstObject(self.currentWriteJobWritten == self.currentWriteJob.length, error);
    [self.pendingWriteJobCallbacks removeObjectAtIndex:0];

    self.currentWriteJobWritten = 0;
    self.currentWriteJob = self.pendingWriteJobs.firstObject;

    if (self.pendingWriteJobs.count) {
        // Dequeue the next job
        [self.pendingWriteJobs removeObjectAtIndex:0];
    }
}

#pragma mark - Sync

- (BOOL)write:(NSData *)data error:(NSError **)error {
    NSUInteger written = 0;
    while (written < data.length) {
        NSInteger status = [self.stream write:(data.bytes + written) maxLength:data.length - written];

        if (status < 1) {
            // Pass back error if any
            if (status < 0 && error) {
                *error = self.stream.streamError;
            }

            return NO;
        }

        // Keep writing
        written += status;
    }

    return YES;
}

#pragma mark - Async

- (void)write:(NSData *)data completion:(TBSocketWriteCallback)callback {
    // Synchronized to protect the thread safety of the current job state
    @synchronized (self.stream) {
        [self.pendingWriteJobCallbacks addObject:callback];

        if (self.currentWriteJob) {
            [self.pendingWriteJobs addObject:data];
        } else {
            self.currentWriteJob = data;
            self.currentWriteJobWritten = 0;

            // Maybe write right now for the job
            if (self.stream.hasSpaceAvailable) {
                [self writeForCurrentWriteJob];
            }
        }
    }
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event {
    [super stream:stream handleEvent:event];

    switch (event) {
        case NSStreamEventHasSpaceAvailable:
            [self writeForCurrentWriteJob];
            break;

            // All of this is handled as we read and write
        default:
            break;
    }
}

@end
