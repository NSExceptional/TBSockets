                                                    //
//  TBServerSocket.m
//  TBIPC
//
//  Created by Tanner on 4/10/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import <TBSockets/TBServerSocket.h>
#include <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <stdio.h>


#define CFSocketCreateTCP(connectCallback, ctx) CFSocketCreate( \
NULL, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketNoCallBack, connectCallback, ctx)

void TBSocketCallbackHandler(CFSocketRef socket, CFSocketCallBackType type,
                             CFDataRef address, const void *data, void *info);

@interface TBServerSocket ()
@property (nonatomic, readonly) dispatch_queue_t acceptQueue;
@end

@implementation TBServerSocket

#pragma mark - Initialization

+ (instancetype)localhost {
    return [self address:@"127.0.0.1" port:0];
}

+ (instancetype)address:(NSString *)address port:(UInt16)port {
    return [[self alloc] initWithAddress:address port:port];
}

+ (instancetype)host:(NSString *)hostname port:(UInt16)port {
    return [[self alloc] initWithAddress:[TBSocketAddress IPAddressFromHost:hostname] port:port];
}

- (id)init {
    return [self initWithAddress:@"127.0.0.1" port:0];
}

- (id)initWithAddress:(NSString *)givenAddr port:(UInt16)port {
    if (self) {
        // Create socket with connection handler
        CFSocketContext context = {
            .version = 0,
            .info = (__bridge void *)self,
            .retain = NULL,
            .release = NULL,
            .copyDescription = NULL
        };
        CFSocketRef socket = CFSocketCreateTCP(&TBSocketCallbackHandler, &context);
        // No automatically reenabling callbacks
        CFSocketSetSocketFlags(socket, 0);

        // Create address
        struct sockaddr_in address;
        memset(&address, 0, sizeof(address));
        address.sin_len         = sizeof(address);
        address.sin_family      = AF_INET;
        address.sin_port        = htons(port);
        address.sin_addr.s_addr = INADDR_ANY;
        if (givenAddr) {
            // 1 = good, 0 = can't parse, -1 = error in errno
            if (inet_pton(AF_INET, givenAddr.UTF8String, &address.sin_addr) < 1) {
                // Fallback to "any address" if
                address.sin_addr.s_addr = INADDR_ANY;
            }
        }

        // Init socket address, return nil on bind() error
        NSData *addressData = [NSData dataWithBytes:&address length:sizeof(address)];
        if (!CFSocketSetAddress(socket, (CFDataRef)addressData)) {
            return [self initWithSocket:socket];
        }
    }

    return nil;
}

- (id)initWithSocket:(CFSocketRef)socket {
    self = [super init];
    if (self) {
        CFSocketNativeHandle handle = CFSocketGetNative(socket);

        // Enable local address reuse
        int on = 1;
        setsockopt(handle, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));

        if (listen(handle, 1024)) {
            // Socket is already connected
            @throw NSInternalInconsistencyException;
        }

        _CFSocket     = socket;
        _localAddress = [TBSocketAddress socket:CFSocketGetNative(socket)];

        NSString *queueName = [NSString stringWithFormat:@"com.nsexceptional.TBSockets.accept_%lx", (unsigned long)socket];
        _acceptQueue = dispatch_queue_create(queueName.UTF8String, DISPATCH_QUEUE_SERIAL);
    }

    return self;
}

- (void)dealloc {
    CFSocketInvalidate(_CFSocket);
}

#pragma mark - Accepting connections

- (TBSocket *)accept:(NSString **)error {
    __block TBSocket *socket = nil;
    dispatch_sync(self.acceptQueue, ^{
        [self _accept:&socket error:error];
    });

    return socket;
}

- (void)acceptWithCallback:(TBServerSocketAcceptCallback)callback {
    dispatch_async(self.acceptQueue, ^{
        TBSocket *socket = nil;
        NSString *error = nil;
        [self _accept:&socket error:&error];
        callback(socket, error);
    });
}

#pragma mark - Private

- (void)_accept:(TBSocket **)socket error:(NSString **)error {
    NSParameterAssert(socket);
    CFSocketNativeHandle handle = accept(CFSocketGetNative(_CFSocket), NULL, NULL);

    if (handle > -1) {
        *socket = [self didAcceptNewConnection:handle];
    } else if (error) {
        *error = [NSString stringWithUTF8String:strerror(errno)];
    }
}

- (TBSocket *)didAcceptNewConnection:(CFSocketNativeHandle)socketHandle {
    // Ignore SIGPIPE signal when connection closes
    int ignoreSIGPIPE = 1;
    setsockopt(socketHandle, SOL_SOCKET, SO_NOSIGPIPE, &ignoreSIGPIPE, sizeof(ignoreSIGPIPE));

    // Create streams, pass to socket
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocket(NULL, socketHandle, &readStream, &writeStream);
    NSInputStream *inputStream = (__bridge_transfer NSInputStream *)readStream;
    NSOutputStream *outputStream = (__bridge_transfer NSOutputStream *)writeStream;
    return [TBSocket input:inputStream output:outputStream];
}

@end

void TBSocketCallbackHandler(CFSocketRef socket, CFSocketCallBackType type,
                             CFDataRef address, const void *data, void *info) {
}
