//
//  DxPlugin.m
//  DataExchanger Cordova Plugin
//
//  (c) 2016 GT-tronics Canada Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "DxPlugin.h"
#import <Cordova/CDV.h>
#import "DxAppSC.h"

@interface DxPlugin()
{
    NSString* _notiCallbackId;
}

@property (nonatomic, strong) DxAppSC* sc;
@property (nonatomic, strong) NSMutableDictionary* callbacks;

@end

@implementation DxPlugin

@synthesize sc;
@synthesize callbacks;

- (void)pluginInitialize {

    NSLog(@"Cordova DataExchanger Plugin");
    NSLog(@"(c)2016 GT-tronics Canada Ltd");

    [super pluginInitialize];

    sc = [DxAppSC controller];
    
    callbacks = [@{} mutableCopy];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bleNotify:)
                                                 name:@"BleNotify"
                                               object:nil];
}

#pragma mark -
#pragma mark - Cordova Plugin Methods

- (void) connect:(CDVInvokedUrlCommand *)command
{
    NSString *uuid = [command.arguments objectAtIndex:0];
    BOOL success = [sc connect:[[NSUUID alloc] initWithUUIDString:uuid]];
    
    // always return OK
    CDVPluginResult *pluginResult = nil;
    if( success )
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"connect failed"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// disconnect: function (device_id, success, failure) {
- (void) disconnect:(CDVInvokedUrlCommand*)command
{
    NSString *uuid = [command.arguments objectAtIndex:0];
    BOOL success = [sc disconnect:[[NSUUID alloc] initWithUUIDString:uuid]];

    // always return OK
    CDVPluginResult *pluginResult = nil;
    if( success )
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"disconnect failed"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) startScan:(CDVInvokedUrlCommand*)command
{
    [sc startScan];
    
    callbacks[@"Scan"] = command.callbackId;
}

- (void) startScanAndConnect:(CDVInvokedUrlCommand*)command
{
    [sc startScan];

    callbacks[@"ScanAndConnect"] = command.callbackId;
}

- (void) stopScan:(CDVInvokedUrlCommand*)command
{
    [sc stopScan];

    if( callbacks[@"Scan"] )
    {
        // Return empty scan results
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{}];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbacks[@"Scan"]];
    }
    
    [callbacks removeObjectForKey:@"Scan"];
    [callbacks removeObjectForKey:@"ScanAndConnect"];
}


- (void) isEnabled:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[sc isEnabled]];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) isConnected:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[sc isConnected]];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) sendData:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult *pluginResult = nil;
    NSData* data = command.arguments[1];
    
    BOOL success = [sc sendData:data];
    
    if( success )
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                     messageAsDictionary:@{@"ErrMsg":@"sendData failed"}];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) sendCmd:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult *pluginResult = nil;
    NSData* data = command.arguments[1];
    
    BOOL success = [sc sendCmd:data];
    
    if( success )
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                     messageAsDictionary:@{@"ErrMsg":@"sendCmd failed"}];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) readTxCredit:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult *pluginResult = nil;
    
    BOOL success = [sc readTxCredit];
    
    if( success )
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                     messageAsDictionary:@{@"ErrMsg":@"readTxCredit failed"}];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) writeTxCreditReportLoopCount:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult *pluginResult = nil;
    uint32_t cnt = [command.arguments[1] unsignedIntValue];
    
    BOOL success = [sc writeTxCreditReportLoopCount:cnt];
    
    if( success )
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                     messageAsDictionary:@{@"ErrMsg":@"writeTxCreditReportLoopCount failed"}];

    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) enableRxDataNotification:(CDVInvokedUrlCommand *)command
{
    callbacks[@"RxData"] = command.callbackId;
}

- (void) disableRxDataNotification:(CDVInvokedUrlCommand *)command
{
    [callbacks removeObjectForKey:@"RxData"];
}

- (void) enableRxCmdNotification:(CDVInvokedUrlCommand *)command
{
    callbacks[@"RxCmd"] = command.callbackId;
}

- (void) disableRxCmdNotification:(CDVInvokedUrlCommand *)command
{
    [callbacks removeObjectForKey:@"RxCmd"];
}

- (void) enableTxCreditNotification:(CDVInvokedUrlCommand *)command
{
    callbacks[@"TxCredit"] = command.callbackId;
}

- (void) disableTxCreditNotification:(CDVInvokedUrlCommand *)command
{
    [callbacks removeObjectForKey:@"TxCredit"];
}

- (void) bleNotify:(NSNotification*)noti
{
    NSDictionary* usrInfo = noti.userInfo;
    NSString* cmd = usrInfo[@"Command"];

    if( [cmd isEqualToString:@"Start"] )
    {
        
    }
    else if( [cmd isEqualToString:@"DeviceOff"] && callbacks[@"ScanAndConnect"])
    {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"state":@"disconnected",
                                                                            @"info":usrInfo[@"DevInfo"]}];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbacks[@"ScanAndConnect"]];

        [[DxAppSC controller] startScan];
    }
    else if( [cmd isEqualToString:@"DeviceOn"] )
    {
    }
    else if( [cmd isEqualToString:@"DeviceReady"] && callbacks[@"ScanAndConnect"] )
    {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"state":@"connected",
                                                                            @"info":usrInfo[@"DevInfo"]}];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbacks[@"ScanAndConnect"]];
    }
    else if( [cmd isEqualToString:@"RxData"] && callbacks[@"RxData"] )
    {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"data":usrInfo[@"Data"],
                                                                            @"info":usrInfo[@"DevInfo"]}];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbacks[@"RxData"]];
    }
    else if( [cmd isEqualToString:@"RxCmd"] && callbacks[@"RxCmd"] )
    {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"data":usrInfo[@"Data"],
                                                                            @"info":usrInfo[@"DevInfo"]}];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbacks[@"RxCmd"]];
    }
    else if( [cmd isEqualToString:@"TxCredit"] && callbacks[@"TxCredit"] )
    {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"credits":usrInfo[@"Credits"],
                                                                            @"info":usrInfo[@"DevInfo"]}];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbacks[@"TxCredit"]];
    }
}

@end
