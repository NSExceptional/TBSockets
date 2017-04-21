# TBSockets

A bare-bones CFSocket/NSStream wrapper, modeled after Java's `Input/OutputStream`, `Socket` and `ServerSocket` classes.

## Usage

##### Synchronous server

```objc
// Begin listening
TBServerSocket *server = [TBServerSocket host:@"domain.com" port:12345];

// Accept a connection and handle error
NSError *error = nil;
TBSocket *socket = [server accept:&error];
if (socket) {
    // Error handling is optional, just pass nil
    NSData *requestData = [socket.inputStream readToLength:N error:nil];
    ...
    NSData *responseData = ...
    if ([socket.outputStream write:responseData error:nil]) {
        // Success
    } else {
        // Not all data could be written; EOF or write error occurred
    }
    
    [socket close];
} else {
    NSLog(error);
}
```

##### Asynchronous server

```objc
// Begin listening
TBServerSocket *server = [TBServerSocket host:@"domain.com" port:12345];

// Accept a connection and handle error
// Calls to this method are serialized and threadsafe
[server acceptWithCallback:^(TBSocket *socket, NSString *error) {
    if (socket) {
        [socket open];
    
        // socket is bound to the current run loop, this could be necessary
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate someDate]];
    
        [socket.inputStream readToLength:N completion:^(NSData *data, NSError *error1) {
            ...
            NSData *responseData = ...
            [socket.outputStream write:responseData completion:^(BOOL finished, NSError *error2) {
                [socket close];
            }];
        }];
    } else {
        NSLog(error);
    }
}];
```

##### Synchronous client

```objc
TBSocket *socket = [TBSocket host:"domain.com" port:12345];
[self.socket open];
NSData *requestData = ...

if (![self.socket.outputStream write:requestData error:nil]) {
    // error occured
}

NSData *responseData = [self.socket.inputStream readToLength:N error:nil];
...
[socket close];
```

##### Asynchronous client

```objc
TBSocket *socket = [TBSocket host:"domain.com" port:12345];
[self.socket open];
NSData *requestData = ...

[socket.outputStream write: requestData completion:^(BOOL finished, NSError *error) {
    if (finished) {
        [socket.inputStream readToLength:self.serverHandshake.length completion:^(NSData *responseData, NSError *error1) {
            ...
            [socket close];
        }];
    }
}];
```
