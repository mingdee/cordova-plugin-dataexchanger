//
//  DxAppSC.m
//  DataExchangerApp
//
//  Created by Ming Leung on 2015-09-24.
//  Copyright © 2015 GT-Tronics HK Ltd. All rights reserved.
//

#import "DxAppSC.h"
#import "BLEController.h"
#import "DataExchangerDevice.h"
#import "DataExchangerProfile.h"

static NSString* const kDevNameDX      = @"DataExchanger";
static DxAppSC* gController = nil;

@interface DxAppSC ()

// BLE
@property (nonatomic, strong)   BLEController*                  bleController;
@property (nonatomic, strong)   DataExchangerDevice*            device;

@end

@implementation DxAppSC

@synthesize bleController;
@synthesize device;
@synthesize enableTxCreditNoti;

+ (DxAppSC*)controller
{
    if( gController == nil )
    {
        gController = [DxAppSC new];
    }
    
    return gController;
}

- (id) init
{
    self = [super init];
    if( self == nil )
    {
        return nil;
    }
    
    //
    // Initialize BLE controller, device, and profile. Please follow these steps:
    //
    // 1. Create BLE controller
    // 2. Create DataExchanger BLE device. DataExchangerDevice should be subclassed from BLEDevice.
    // 3. Create DataExchanger BLE profile. DataExchangerProfile has already been implemented in libblelib.a.
    // 4. Bind DataExchangerProfile with DataExchangerDevice.
    // 5. Bind DataExchangerDevice with BLE controller.
    //
    if( bleController == nil )
    {
        // 1. Create BLE controller
        [BLEController enablePrivateCentralQueue];
        bleController = [BLEController controller];
        bleController.scanDevicePolicy = SCAN_ALLOW_DUPLICATED_KEY;
        
        // 2. Create DataExchanger device
        device = [DataExchangerDevice deviceWithAppDelegate:self];
        device.devName = [NSString stringWithString:kDevNameDX];
        
        // 3. Create DataExchanger profile
        BLEProfile* dxp = [DataExchangerProfile profileWithDevice:device andAppDelegate:self];
        
        // 4. Add DataExchanger profile in DataExchanger device
        [device addProfile:dxp];
        
        // 5. Register DataExchanger device with BLE controller
        [bleController registerDevice:device];
    }
    
    return self;
}

- (BOOL) isConnected
{
    return device.state == BLE_DEVICE_CONNECTED;
}

- (void) startScan
{
    if( device.state == BLE_DEVICE_IDLE )
    {
        [bleController startScan];
    }
}

- (void) stopScan
{
    [bleController stopScan];
}

- (BOOL) connect:(NSUUID*)uuid
{
    return NO;
}

- (BOOL) disconnect:(NSUUID*)uuid
{
    return NO;
}

- (BOOL) sendData:(NSData *)data
{
    return [device sendData:data];
}

- (BOOL) sendCmd:(NSData *)data
{
    return [device sendCmd:data];
}

- (BOOL) readTxCredit
{
    return [device readTxCredit];
}

- (BOOL) writeTxCreditReportLoopCount:(uint32_t)count
{
    return [device writeTxCreditReportLoopCount:count];
}

#pragma mark -
#pragma mark - BLEDeviceAppDelegateProtocol methods

// This member function is called when the device is discovered and
// connected or is disconnected. This function is called before
// Device:allProfilesReady:.
- (void) Device:(BLEDevice*)d switchOn:(BOOL)flag
{
    //
    // Receive notification of device status change
    //
    
    device = (DataExchangerDevice*)d;
    
    if( flag == NO )
    {
        //
        // Device is disconnected.
        //
        [[NSNotificationCenter defaultCenter] postNotificationName:@"BleNotify"
                                                            object:nil
                                                          userInfo:@{
                                                                     @"Command":@"DeviceOff",
                                                                     @"DevInfo":@{
                                                                                    @"UUID":[d.devUUID UUIDString]
                                                                                 }
                                                                    }];
    }
    else
    {
        //
        // Device is discovered and connected. But its service and characteristics
        // are not fully discovered yet.
        //
        [[NSNotificationCenter defaultCenter] postNotificationName:@"BleNotify"
                                                            object:nil
                                                          userInfo:@{
                                                                     @"Command":@"DeviceOn",
                                                                     @"DevInfo":@{
                                                                                    @"UUID":[d.devUUID UUIDString]
                                                                                }
                                                                     }];
    }
}

// This member function is called when all profiles declared ready
// At this point, you are sure the device can function in all aspects
- (void) Device:(BLEDevice*)d allProfilesReady:(BOOL)isReady
{
    if( isReady )
    {
        //
        // Device is fully ready
        //
        
        // Don't remove the next line
        device = (DataExchangerDevice*)d;
        
        // Uncomment next line to enable RSSI reading
        //[device enableRssiReadingWithNotification:YES howFrequent:1.0];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"BleNotify"
                                                            object:nil
                                                          userInfo:@{
                                                                     @"Command":@"DeviceReady",
                                                                     @"DevInfo":@{
                                                                                    @"UUID":[d.devUUID UUIDString]
                                                                                 }
                                                                    }];
    }
}

// This function is called when RSSI reading is enabled.
- (void) Device:(BLEDevice*)device reportRssi:(NSNumber *)rssi
{
    //
    // Recieve new RSSI reading
    //
    
    //NSLog(@"INFO: reportRssi [%@]", rssi];
}

#pragma mark -
#pragma mark - DataExchangerProfileProtocol methods

// This member function is called when data is ready to be received.
- (void) Device:(BLEDevice *)d RxData:(NSData *)data
{
    //
    // Receive data from the device
    //
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BleNotify"
                                                        object:nil
                                                      userInfo:@{@"Command":@"RxData",
                                                                 @"Data":data,
                                                                 @"DevInfo":@{
                                                                                @"UUID":[d.devUUID UUIDString]
                                                                             }
                                                                 }];
}

- (void) Device:(BLEDevice*)d DidWriteWithError:(NSError*)error
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BleNotify"
                                                        object:nil
                                                      userInfo:@{@"Command":@"DidSend",
                                                                 @"Error":error == nil ?[NSNull null] :error,
                                                                 @"DevInfo":@{
                                                                                @"UUID":[d.devUUID UUIDString]
                                                                             }
                                                                 }];

}

- (void) Device:(BLEDevice *)d Rx2Data:(NSData *)data
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BleNotify"
                                                        object:nil
                                                      userInfo:@{@"Command":@"RxCmd",
                                                                 @"Data":data,
                                                                 @"DevInfo":@{
                                                                                @"UUID":[d.devUUID UUIDString]
                                                                             }
                                                                 }];
}

- (void) Device:(BLEDevice *)d TxCredit:(UInt32)credits
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BleNotify"
                                                        object:nil
                                                      userInfo:@{@"Command":@"TxCredit",
                                                                 @"Credits":[NSNumber numberWithUnsignedInt:credits],
                                                                 @"DevInfo":@{
                                                                                @"UUID":[d.devUUID UUIDString]
                                                                             }
                                                                 }];
}

@end
