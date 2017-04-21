//
//  TBSocketAddress.m
//  TBIPC
//
//  Created by Tanner on 4/11/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import <TBSockets/TBSocketAddress.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>


@implementation TBSocketAddress

#pragma mark - Initialization

+ (instancetype)socket:(CFSocketNativeHandle)handle {
    TBSocketAddress *address = [self new];
    address->_port      = [self portFromSocket:handle];
    address->_IPAddress = [self IPAddressFromSocket:handle];
    address->_host      = [self hostFromIPAddress:address->_IPAddress];
    return address;
}

#pragma mark - Description / Equality

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %@:%@ host=%@>",
            NSStringFromClass(self.class), self.IPAddress, @(self.port), self.host];
}

#pragma mark - Class methods

+ (UInt16)portFromSocket:(CFSocketNativeHandle)handle {
    socklen_t namelen = SOCK_MAXADDRLEN;
    struct sockaddr *address = alloca(namelen);

    if (getsockname(handle, address, &namelen)) {
        return 0;
    }

    // Differentiate between IPv4 and IPv6
    if (address->sa_family == AF_INET) {
        struct sockaddr_in *socketAddress = (struct sockaddr_in*)address;
        return ntohs(socketAddress->sin_port);
    } else if (address->sa_family == AF_INET6) {
        struct sockaddr_in6 *socketAddress = (struct sockaddr_in6*)address;
        return ntohs(socketAddress->sin6_port);
    } else {
        return 0;
    }
}

+ (NSString *)IPAddressFromSocket:(CFSocketNativeHandle)handle {
    socklen_t namelen = SOCK_MAXADDRLEN;
    struct sockaddr *address = alloca(namelen);

    if (getsockname(handle, address, &namelen)) {
        return nil;
    }

    int type;
    socklen_t length;
    const void *ipAddress;

    // Differentiate between IPv4 and IPv6
    if (address->sa_family == AF_INET) {
        struct sockaddr_in *socketAddress = (struct sockaddr_in*)address;
        type = AF_INET;
        length = INET_ADDRSTRLEN;
        ipAddress = &socketAddress->sin_addr;
    } else if (address->sa_family == AF_INET6) {
        struct sockaddr_in6 *socketAddress = (struct sockaddr_in6*)address;
        type = AF_INET6;
        length = INET6_ADDRSTRLEN;
        ipAddress = &socketAddress->sin6_addr;
    } else {
        return nil;
    }

    // Convert address to string
    char ipString[length];
    inet_ntop(type, ipAddress, ipString, length);

    return [NSString stringWithUTF8String:ipString];
}

+ (NSString *)IPAddressFromHost:(NSString *)hostname {
    if (!hostname.length) {
        return nil;
    }

    struct hostent *host = gethostbyname(hostname.UTF8String);
    if (host) {
        return [NSString stringWithUTF8String:inet_ntoa(**(struct in_addr **)host->h_addr_list)];
    }

    return nil;
}

+ (NSString *)hostFromSocket:(CFSocketNativeHandle)handle {
    return [self hostFromIPAddress:[self IPAddressFromSocket:handle]];
}

+ (NSString *)hostFromIPAddress:(NSString *)address {
    if (!address.length) {
        return nil;
    }

    struct in_addr ip;
    struct hostent *host;

    if (!inet_aton(address.UTF8String, &ip) ||
        !(host = gethostbyaddr(&ip, sizeof(struct in_addr), AF_INET))) {
        // Can't parse, or no host name associated with address
        return nil;
    } else {
        return [NSString stringWithUTF8String:host->h_name];
    }
}

@end
