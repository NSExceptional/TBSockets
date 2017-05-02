//
//  TBSocket.h
//  TBIPC
//
//  Created by Tanner on 4/10/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TBSocketAddress.h>
#import <TBInputStream.h>
#import <TBOutputStream.h>


/// Socket must be opened before using either of the streams.
///
/// "localhost" or "127.0.0.1" is the default for all
/// invalid or missing addresses or host names.
@interface TBSocket : NSObject

#pragma mark - Initialization
+ (instancetype)host:(NSString *)url port:(UInt16)port;
+ (instancetype)address:(NSString *)address port:(UInt16)port;
+ (instancetype)input:(NSInputStream *)input output:(NSOutputStream *)output;

#pragma mark - Properties
@property (nonatomic, readonly) TBSocketAddress *localAddress;
@property (nonatomic, readonly) TBSocketAddress *remoteAddress;

@property (nonatomic, readonly) TBInputStream *inputStream;
@property (nonatomic, readonly) TBOutputStream *outputStream;

/// Sets the runLoop property of each stream.
- (void)setStreamsRunLoop:(NSRunLoop *)runLoop;

#pragma mark - Methods
- (void)open;
- (void)close;

@end
