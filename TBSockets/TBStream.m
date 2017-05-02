//
//  TBStream.m
//  TBSockets
//
//  Created by Tanner on 5/2/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import "TBStream.h"


@interface TBStream ()
@property (nonatomic, readonly) void(^openCallback)(TBStream *);
@end

@implementation TBStream

#pragma mark Initialization

+ (instancetype)from:(NSStream *)stream {
    // TODO file a radar so this cast isn't necessary,
    // it's giving me a warning for -[NSXMLParser initWithStream:]
    return [(TBStream *)[self alloc] initWithStream:stream];
}

- (id)initWithStream:(NSStream *)stream {
    // DO NOT change to super
    self = [self init];
    if (self) {
        _runLoop = [NSRunLoop mainRunLoop];
        _stream = stream;
        stream.delegate = self;
    }

    return self;
}

- (void)dealloc {
    if (_isOpen) {
        [self close];
    }
}

#pragma mark Open / close

- (void)setRunLoop:(NSRunLoop *)runLoop {
    NSParameterAssert(runLoop);

    @synchronized (_stream) {
        if (_isOpen) {
            [self.stream scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
            [self.stream removeFromRunLoop:self.runLoop forMode:NSDefaultRunLoopMode];
        }

        _runLoop = runLoop;
    }
}

- (void)open:(void(^)(TBStream *stream))openCallback {
    _openCallback = openCallback;

    @synchronized (_stream) {
        [self.stream scheduleInRunLoop:self.runLoop forMode:NSDefaultRunLoopMode];
    }

    [self.stream open];
    _isOpen = YES;
}

- (void)close {
    assert(!_isClosed);

    @synchronized (_stream) {
        [self.stream removeFromRunLoop:self.runLoop forMode:NSDefaultRunLoopMode];
    }

    [self.stream close];
    _runLoop  = nil;
    _isClosed = YES;
    _isOpen   = NO;
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event {
    switch (event) {
        case NSStreamEventOpenCompleted:
            self.openCallback(self);
            _openCallback = nil;
            break;

        default:
            break;
    }
}

@end
