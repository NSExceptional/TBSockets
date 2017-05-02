//
//  TBStream.h
//  TBSockets
//
//  Created by Tanner on 5/2/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface TBStream : NSObject <NSStreamDelegate>

#pragma mark - Initialization
+ (instancetype)from:(NSStream *)stream;

#pragma mark - Properties
@property (nonatomic, readonly) NSStream *stream;
@property (nonatomic          ) NSRunLoop *runLoop;
/// YES only if the stream has been opened and not yet closed.
@property (nonatomic, readonly) BOOL isOpen;
/// YES only if the stream has been closed after having been opened.
@property (nonatomic, readonly) BOOL isClosed;

#pragma mark - Open / Close
- (void)open:(void(^)(TBStream *stream))openCallback;
- (void)close;

@end
