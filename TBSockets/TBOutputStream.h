//
//  TBOutputStream.h
//  TBIPC
//
//  Created by Tanner on 4/10/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import <TBStream.h>


typedef void(^TBSocketWriteCallback)(BOOL finished, NSError *error);

/// Behavior is undefined if you perform an async operation followed
/// by a synchronous operation before the async operation completes.
///
/// Async operations are thread-safe and serialized.
@interface TBOutputStream : TBStream

@property (nonatomic, readonly) NSOutputStream *stream;

#pragma mark - Synchronous
/// Writes until the stream reaches capacity or until an error occurs (returned in error param)
/// @return YES if all of the data was successfully written, NO otherwise
- (BOOL)write:(NSData *)data error:(NSError **)error;

#pragma mark Asynchronous
/// In the completion block, returns whether all data was successfully written.
- (void)write:(NSData *)data completion:(TBSocketWriteCallback)callback;

@end
