//
//  TBServerSocket.h
//  TBIPC
//
//  Created by Tanner on 4/10/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TBSocket.h>


typedef void(^TBServerSocketAcceptCallback)(TBSocket *socket, NSString *error);

/// +new will use localhost and a random port.
@interface TBServerSocket : NSObject

#pragma mark - Initialization
+ (instancetype)localhost;
/// Pass nil as the address to listen on all interfaces.
/// @param address an IPv4 address. Ignored if it can't be parsed.
/// @param port pass 0 to use a random port.
+ (instancetype)address:(NSString *)address port:(UInt16)port;
/// Pass nil as the host to listen on all interfaces.
/// @param hostname a host name, such as "localhost". Ignored if it can't be parsed.
/// @param port pass 0 to use a random port.
+ (instancetype)host:(NSString *)hostname port:(UInt16)port;

#pragma mark - Properties
@property (nonatomic, readonly) CFSocketRef CFSocket;
@property (nonatomic, readonly) TBSocketAddress *localAddress;

#pragma mark - Methods
- (TBSocket *)accept:(NSString **)error;
- (void)acceptWithCallback:(TBServerSocketAcceptCallback)callback;

@end
