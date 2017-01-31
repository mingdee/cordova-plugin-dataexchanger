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
@property (nonatomic, strong) NSMutableDictionary* bkupCallbacks;

@end

@implementation DxPlugin

@synthesize sc;
@synthesize callbacks;
@synthesize bkupCallbacks;

- (void) suspendCallbacks
{
    bkupCallbacks = callbacks;
    callbacks = [@{} mutableCopy];
}

- (void) resumeCallbacks
{
    if( bkupCallbacks )
    {
        callbacks = bkupCallbacks;
        bkupCallbacks = nil;
    }
}

- (void)pluginInitialize {

    NSLog(@"Cordova DataExchanger Plugin");
    NSLog(@"(c)2016 GT-tronics Canada Ltd");

    [super pluginInitialize];

}

#pragma mark -
#pragma mark - Cordova Plugin Methods

- (void) init:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult = nil;
    if( sc )
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"already initialized"];
    }
    else
    {
        NSUInteger devCount = command.arguments.count > 0 ?[[command.arguments objectAtIndex:0] integerValue] :1;
        float pwrLevel = command.arguments.count > 1 ?[[command.arguments objectAtIndex:1] floatValue] :-127.0;
        NSTimeInterval timeout = command.arguments.count > 2 ?[[command.arguments objectAtIndex:2] doubleValue] :5.0;
        BOOL autoConnect = command.arguments.count > 3 ?[[command.arguments objectAtIndex:3] boolValue] :NO;
        BOOL enableCmdChannel = command.arguments.count > 4 ?[[command.arguments objectAtIndex:4] boolValue] :NO;
        BOOL enableTxCredit = command.arguments.count > 5 ?[[command.arguments objectAtIndex:5] boolValue] :NO;
        
        sc = [[DxAppSC alloc] initWithDeviceCount:devCount proximityPowerLevel:pwrLevel discoveryActiveTimeout:timeout autoConnect:autoConnect enableCommandChannel:enableCmdChannel enableTransmitBackPressure:enableTxCredit];
        [DxAppSC assignToController:sc byDelegate:self];
        
        callbacks = [@{} mutableCopy];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(bleNotify:)
                                                     name:@"BleNotify"
                                                   object:nil];

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) connect:(CDVInvokedUrlCommand *)command
{
    NSString* uuid = [command.arguments objectAtIndex:0];
    NSString* cbLabel = [NSString stringWithFormat:@"Connect_%@", uuid];
    BOOL success = [sc connectDevice:[[NSUUID alloc] initWithUUIDString:uuid]];
    
    if( !success )
    {
        CDVPluginResult *pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"connect failed"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    callbacks[cbLabel] = command.callbackId;
}

// disconnect: function (device_id, success, failure) {
- (void) disconnect:(CDVInvokedUrlCommand*)command
{
    NSString *uuid = [command.arguments objectAtIndex:0];
    BOOL success = [sc disconnectDevice:[[NSUUID alloc] initWithUUIDString:uuid]];

    if( !success )
    {
        CDVPluginResult *pluginResult = nil;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"disconnect failed"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void) startScan:(CDVInvokedUrlCommand*)command
{
    [sc startScan];
    
    callbacks[@"Scan"] = command.callbackId;
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
}


- (void) isEnabled:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[sc isEnabled]];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) isConnected:(CDVInvokedUrlCommand*)command
{
    NSString *uuid = [command.arguments objectAtIndex:0];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[sc isDeviceConnected:[[NSUUID alloc] initWithUUIDString:uuid]]];
    
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
    NSString* uuid = [command.arguments objectAtIndex:0];
    NSString* key = [NSString stringWithFormat:@"RxData_%@", uuid];

    callbacks[key] = command.callbackId;
}

- (void) disableRxDataNotification:(CDVInvokedUrlCommand *)command
{
    NSString* uuid = [command.arguments objectAtIndex:0];
    NSString* key = [NSString stringWithFormat:@"RxData_%@", uuid];
    
    [callbacks removeObjectForKey:key];
}

- (void) enableRxCmdNotification:(CDVInvokedUrlCommand *)command
{
    NSString* uuid = [command.arguments objectAtIndex:0];
    NSString* key = [NSString stringWithFormat:@"RxCmd_%@", uuid];
    
    callbacks[key] = command.callbackId;
}

- (void) disableRxCmdNotification:(CDVInvokedUrlCommand *)command
{
    NSString* uuid = [command.arguments objectAtIndex:0];
    NSString* key = [NSString stringWithFormat:@"RxCmd_%@", uuid];
    
    [callbacks removeObjectForKey:key];
}

- (void) enableTxCreditNotification:(CDVInvokedUrlCommand *)command
{
    NSString* uuid = [command.arguments objectAtIndex:0];
    NSString* key = [NSString stringWithFormat:@"TxCredit_%@", uuid];
    
    callbacks[key] = command.callbackId;
}

- (void) disableTxCreditNotification:(CDVInvokedUrlCommand *)command
{
    NSString* uuid = [command.arguments objectAtIndex:0];
    NSString* key = [NSString stringWithFormat:@"TxCredit_%@", uuid];
    
    [callbacks removeObjectForKey:key];
}

- (void) bleNotify:(NSNotification*)noti
{
    NSDictionary* usrInfo = noti.userInfo;
    NSString* cmd = usrInfo[@"Command"];
    NSString* uuid = usrInfo[@"DevInfo"][@"UUID"];
    NSString* connectLabel = [NSString stringWithFormat:@"Connect_%@", uuid];
    NSString* rxCmdLabel = [NSString stringWithFormat:@"RxCmd_%@", uuid];
    NSString* rxDataLabel = [NSString stringWithFormat:@"RxData_%@", uuid];
    NSString* txCreditLabel = [NSString stringWithFormat:@"TxCredit_%@", uuid];
    

    if( [cmd isEqualToString:@"Start"] )
    {
        
    }
    else if( [cmd isEqualToString:@"DeviceDiscOff"] && callbacks[@"Scan"])
    {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"state":@"inactive",
                                                                            @"info":usrInfo[@"DevInfo"]}];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbacks[@"Scan"]];
    }
    else if( [cmd isEqualToString:@"DeviceDiscOn"] && callbacks[@"Scan"])
    {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"state":@"active",
                                                                            @"info":usrInfo[@"DevInfo"]}];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbacks[@"Scan"]];
    }
    else if( [cmd isEqualToString:@"DeviceOff"] && callbacks[connectLabel])
    {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"state":@"disconnected",
                                                                            @"info":usrInfo[@"DevInfo"]}];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbacks[connectLabel]];
    }
    else if( [cmd isEqualToString:@"DeviceOn"] )
    {
    }
    else if( [cmd isEqualToString:@"DeviceReady"] && callbacks[connectLabel] )
    {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"state":@"connected",
                                                                            @"info":usrInfo[@"DevInfo"]}];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbacks[connectLabel]];
    }
    else if( [cmd isEqualToString:@"RxData"] && callbacks[rxDataLabel] )
    {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"data":usrInfo[@"Data"],
                                                                            @"info":usrInfo[@"DevInfo"]}];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbacks[rxDataLabel]];
    }
    else if( [cmd isEqualToString:@"RxCmd"] && callbacks[rxCmdLabel] )
    {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"data":usrInfo[@"Data"],
                                                                            @"info":usrInfo[@"DevInfo"]}];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbacks[rxCmdLabel]];
    }
    else if( [cmd isEqualToString:@"TxCredit"] && callbacks[txCreditLabel] )
    {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:@{@"credits":usrInfo[@"Credits"],
                                                                            @"info":usrInfo[@"DevInfo"]}];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbacks[txCreditLabel]];
    }
}

@end
