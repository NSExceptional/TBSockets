//
//  TBSocketAddress.h
//  TBIPC
//
//  Created by Tanner on 4/11/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface TBSocketAddress : NSObject

#pragma mark - Initialization
+ (instancetype)socket:(CFSocketNativeHandle)handle;

#pragma mark - Properties
@property (nonatomic, readonly) NSString *IPAddress;
@property (nonatomic, readonly) NSString *host;
@property (nonatomic, readonly) UInt16 port;

#pragma mark - Class methods
+ (UInt16)portFromSocket:(CFSocketNativeHandle)handle;
/// Assumes host is prefixed with "http://" or "https://"
+ (NSString *)IPAddressFromSocket:(CFSocketNativeHandle)handle;
/// Assumes host is prefixed with "http://" or "https://"
+ (NSString *)IPAddressFromHost:(NSString *)host;
+ (NSString *)hostFromSocket:(CFSocketNativeHandle)handle;
+ (NSString *)hostFromIPAddress:(NSString *)address;

@end
