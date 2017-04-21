//
//  TBSocketsTests.m
//  TBSocketsTests
//
//  Created by Tanner on 4/12/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TBServerSocket.h"
#include <arpa/inet.h>

#define EXPECT __expct = [self expectationWithDescription:@"Callback"];
#define WAIT(timeout) [self waitForExpectationsWithTimeout:timeout handler:nil];
#define FINISH [__expct fulfill];

@interface TBSocketsTests : XCTestCase
@property (nonatomic, readonly) TBServerSocket *factory;
@property (nonatomic, readonly) TBSocket *socket;

@property (nonatomic) UInt16 port;
@property (nonatomic) NSString *host;

@property (nonatomic) NSString *clientHandshake;
@property (nonatomic) NSData *clientHandshakeData;
@property (nonatomic) NSString *serverHandshake;
@property (nonatomic) NSData *serverHandshakeData;

@property (nonatomic) XCTestExpectation *_expct;
@end

@implementation TBSocketsTests

- (void)setUp {
    [super setUp];
    self.host = @"localhost";
    self.port = 44444;

    self.clientHandshake = @"tanner\n";
    self.clientHandshakeData = [self.clientHandshake dataUsingEncoding:NSUTF8StringEncoding];
    self.serverHandshake = @"bennett\n";
    self.serverHandshakeData = [self.serverHandshake dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)testServer { EXPECT
    _factory = [TBServerSocket host:self.host port:self.port];
    [self.factory acceptWithCallback:^(TBSocket *server, NSString *error) {
        [server open];
        NSData *input = [server.inputStream readToLength:self.clientHandshake.length error:nil];
        NSString *inputString = [[NSString alloc] initWithData:input encoding:NSUTF8StringEncoding];

        XCTAssertEqualObjects(self.clientHandshake, inputString);
        XCTAssert([server.outputStream write:self.serverHandshakeData error:nil]);
        [server close];
        FINISH
    }];

    WAIT(30)
}

- (void)testClient {
    _socket = [TBSocket host:self.host port:self.port];
    [self.socket open];
    XCTAssert([self.socket.outputStream write:self.clientHandshakeData error:nil]);
    NSData *input = [self.socket.inputStream readToLength:self.serverHandshake.length error:nil];
    NSString *inputString = [[NSString alloc] initWithData:input encoding:NSUTF8StringEncoding];

    XCTAssertEqualObjects(self.serverHandshake, inputString);
    [self.socket close];
}

- (void)testServerAsync { EXPECT
    _factory = [TBServerSocket host:self.host port:self.port];
    [self.factory acceptWithCallback:^(TBSocket *server, NSString *error) {
        _socket = server;
        XCTAssertNotNil(server);
        XCTAssertNil(error);
        [server open];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:120]];

        [_socket.inputStream readToLength:self.clientHandshake.length completion:^(NSData *data, NSError *error1) {
            XCTAssertNotNil(data);
            XCTAssertNil(error1);
            NSString *inputString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            XCTAssertEqualObjects(self.clientHandshake, inputString);

            FINISH
        }];
    }];

    [self waitForExpectationsWithTimeout:120 handler:^(NSError *error) { EXPECT
        XCTAssertNil(error);

        [_socket.outputStream write:self.serverHandshakeData completion:^(BOOL finished, NSError *error2) {
            XCTAssert(finished);
            XCTAssertNil(error2);
            [_socket close];

            FINISH
        }];

        WAIT(30)
    }];
}

- (void)testClientAsync { EXPECT
    _socket = [TBSocket host:self.host port:self.port];
    [self.socket open];

    [self.socket.outputStream write:self.clientHandshakeData completion:^(BOOL finished, NSError *error) {
        XCTAssert(finished);
        XCTAssertNil(error);
        FINISH
    }];

    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) { EXPECT
        XCTAssertNil(error);

        [self.socket.inputStream readToLength:self.serverHandshake.length completion:^(NSData *data, NSError *error1) {
            XCTAssertNotNil(data);
            XCTAssertNil(error1);
            NSString *inputString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            XCTAssertEqualObjects(self.serverHandshake, inputString);
            [self.socket close];

            FINISH
        }];

        WAIT(30)
    }];
}

@end
