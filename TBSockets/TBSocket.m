//
//  TBSocket.m
//  TBIPC
//
//  Created by Tanner on 4/10/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import <TBSocket.h>
#include <arpa/inet.h>
#include <netdb.h>


NSString * const kLocalHost = @"127.0.0.1";

@interface TBSocket ()
@end

@implementation TBSocket

#pragma mark - Initialization

+ (instancetype)host:(NSString *)url port:(UInt16)port {
    // Convert host name to IP address
    NSString *address = [TBSocketAddress IPAddressFromHost:[NSURL URLWithString:url].host] ?: kLocalHost;
    return [self address:address port:port];
}

+ (instancetype)address:(NSString *)address port:(UInt16)port {
    if (!address.length) {
        address = kLocalHost;
    }

    // Create socket streams
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)address, port, &readStream, &writeStream);
    NSInputStream *inputStream = (__bridge_transfer NSInputStream *)readStream;
    NSOutputStream *outputStream = (__bridge_transfer NSOutputStream *)writeStream;
    
    return [self input:inputStream output:outputStream];
}

+ (instancetype)input:(NSInputStream *)input output:(NSOutputStream *)output {
    NSParameterAssert(input); NSParameterAssert(output);

    TBSocket *socket      = [self new];
    socket->_inputStream  = [TBInputStream from:input];
    socket->_outputStream = [TBOutputStream from:output];
    [input setProperty:NSStreamSocketSecurityLevelNone forKey:NSStreamSocketSecurityLevelKey];
    [output setProperty:NSStreamSocketSecurityLevelNone forKey:NSStreamSocketSecurityLevelKey];

    return socket;
}

#pragma mark - Public

- (void)setStreamsRunLoop:(NSRunLoop *)runLoop {
    self.inputStream.runLoop = runLoop;
    self.outputStream.runLoop = runLoop;
}

- (void)open {
    CFStringRef key = kCFStreamPropertySocketNativeHandle;

    [self.inputStream open:^(TBStream *stream) {
        // Address stuff
        CFDataRef localSocket = (CFDataRef)CFReadStreamCopyProperty((__bridge_retained CFReadStreamRef)stream.stream, key);
        CFSocketNativeHandle handle;
        CFDataGetBytes(localSocket, CFRangeMake(0, sizeof(CFSocketNativeHandle)), (UInt8 *)&handle);
        _localAddress = [TBSocketAddress socket:handle];
    }];
    [self.outputStream open:^(TBStream *stream) {
        // Address stuff
        CFDataRef remoteSocket = (CFDataRef)CFWriteStreamCopyProperty((__bridge_retained CFWriteStreamRef)stream.stream, key);
        CFSocketNativeHandle handle;
        CFDataGetBytes(remoteSocket, CFRangeMake(0, sizeof(CFSocketNativeHandle)), (UInt8 *)&handle);
        _remoteAddress = [TBSocketAddress socket:handle];
    }];
}

- (void)close {
    [self.inputStream close];
    [self.outputStream close];
}

@end
