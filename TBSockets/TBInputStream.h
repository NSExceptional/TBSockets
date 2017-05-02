//
//  TBInputStream.h
//  TBIPC
//
//  Created by Tanner on 4/10/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import <TBStream.h>


typedef void(^TBSocketReadCallback)(NSData *data, NSError *error);

/// Behavior is undefined if you perform an async operation followed
/// by a synchronous operation before the async operation completes.
///
/// Async operations are thread-safe and serialized.
@interface TBInputStream : TBStream

@property (nonatomic, readonly) NSInputStream *stream;

#pragma mark - Convenience
/// Reads a single byte
- (NSNumber *)read8;
/// Reads two bytes
- (NSNumber *)read16;
/// Reads 4 bytes
- (NSNumber *)read32;
/// Reads 8 bytes
- (NSNumber *)read64;

#pragma mark - Synchronous
/// Reads until the stream reaches EOF or until an error occurs (returned in error param)
/// @return The data read, or nil if no data was read.
- (NSData *)readToLength:(NSUInteger)length error:(NSError **)error;

#pragma mark Asynchronous
/// In the completion block, returns the data read, or nil if no data was read.
- (void)readToLength:(NSUInteger)length completion:(TBSocketReadCallback)callback;

@end
