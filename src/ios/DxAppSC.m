//
//  DxAppSC.m
//  DataExchangerApp
//
//  Created by Ming Leung on 2015-09-24.
//  Copyright © 2015 GT-Tronics HK Ltd. All rights reserved.
//

#import "DxAppSC.h"
#import "BLEController.h"
#import "DataExchangerProfile.h"

static NSString* const kDevNameDX      = @"DataExchanger";
static DxAppSC* gController = nil;

@interface DxAppSC ()

// BLE
@property (nonatomic, strong)   BLEController*                  bleController;
@property (nonatomic, strong)   DataExchangerDevice*            device;
@property (nonatomic, strong)   NSMutableDictionary*            activeDevices;
@property (nonatomic, strong)   NSMutableDictionary*            connectedDevices;
@property (nonatomic, strong)   NSMutableSet*                   allDevices;

@end

@implementation DxAppSC

@synthesize bleController;
@synthesize device;
@synthesize enableTxCreditNoti;
@synthesize activeDevices;
@synthesize connectedDevices;
@synthesize allDevices;

+ (DxAppSC*)controller
{
    if( gController == nil )
    {
        gController = [[DxAppSC alloc] initWithDeviceCount:1 proximityPowerLevel:-127 discoveryActiveTimeout:5.0];
    }
    
    return gController;
}

- (id) initWithDeviceCount:(NSUInteger)devCount proximityPowerLevel:(float)pwrLevel discoveryActiveTimeout:(NSTimeInterval)timeout
{
    self = [super init];
    if( self == nil )
    {
        return nil;
    }
    
    activeDevices = [@{} mutableCopy];
    connectedDevices = [@{} mutableCopy];
    allDevices = [NSMutableSet set];
    
    //
    // Initialize BLE controller, device, and profile. Please follow these steps:
    //
    // 1. Create BLE controller
    // 2. Create DataExchanger BLE device. DataExchangerDevice should be subclassed from BLEDevice.
    // 3. Create DataExchanger BLE profile. DataExchangerProfile has already been implemented in libblelib.a.
    // 4. Bind DataExchangerProfile with DataExchangerDevice.
    // 5. Bind DataExchangerDevice with BLE controller.
    //
    // 1. Create BLE controller
    [BLEController enablePrivateCentralQueue];
    bleController = [BLEController controller];
    bleController.scanDevicePolicy = SCAN_ALLOW_DUPLICATED_KEY;

    for( int i=0; i < devCount; i++)
    {
        // 2. Create DataExchanger device
        device = [DataExchangerDevice deviceWithAppDelegate:self];
        device.devName = [NSString stringWithString:kDevNameDX];
        device.autoConnect = NO;
        device.discoveryActiveTimeout = timeout;
        if( pwrLevel <= -127 )
        {
            device.proximityConnecting = NO;
        }
        else
        {
            device.proximityConnecting = YES;
            if( pwrLevel > -35 )
            {
                pwrLevel = -35;
            }
            device.minPowerLevel = pwrLevel;
        }
        
        // 3. Create DataExchanger profile
        BLEProfile* dxp = [DataExchangerProfile profileWithDevice:device andAppDelegate:self];
        
        // 4. Add DataExchanger profile in DataExchanger device
        [device addProfile:dxp];
        
        // 5. Register DataExchanger device with BLE controller
        [bleController registerDevice:device];
        
        [allDevices addObject:device];
    }
    
    return self;
}

- (BOOL) isEnabled
{
    return [bleController isBluetoothOn];
}

- (void) startScan
{
    NSMutableSet* unconnected = [allDevices copy];
    if( connectedDevices.count > 0 )
    {
        [unconnected minusSet:[NSSet setWithArray:connectedDevices.allValues]];
    }
    if( unconnected.count > 0 )
    {
        [bleController startScan];
    }
}

- (void) stopScan
{
    [bleController stopScan];
}

- (BOOL) isScanning
{
    return [bleController isScanning];
}

- (BOOL) isDeviceActive:(NSUUID*)uuid
{
    DataExchangerDevice* d = activeDevices[uuid];
    
    return d ?YES :NO;
}

- (BOOL) isDeviceConnected:(NSUUID*)uuid
{
    DataExchangerDevice* d = connectedDevices[uuid];
    
    return d ?YES :NO;
}

- (NSUInteger) connectedDeviceCount
{
    return connectedDevices.count;
}

- (BOOL) connectDevice:(NSUUID*)uuid
{
    return [bleController connectDevice:uuid];
}

- (BOOL) disconnectDevice:(NSUUID*)uuid
{
    return [bleController disconnectDevice:uuid];
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
#pragma mark - DataExchangerDeviceAppDelegateProtocol methods

// This member function is called when DataExchangerDevice reports discovery activity.
// Please note this is called only when autoConnect is set NO
- (void) Device:(DataExchangerDevice *)d active:(BOOL)isActive parameters:(NSDictionary *)params
{
    CBUUID* cbUUID = params[@"CBUUID"];
    NSUUID* devUUID = [[NSUUID alloc] initWithUUIDString:[cbUUID UUIDString]];
    
    activeDevices[devUUID] = isActive ?d :nil;

    NSString* name = @"Unknown";
    NSString* nameFromAdv = params[@"ADV"][@"kCBAdvDataLocalName"];
    if( nameFromAdv )
    {
        name = nameFromAdv;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BleNotify"
                                                        object:nil
                                                      userInfo:@{
                                                                 @"Command":isActive ?@"DeviceDiscOn" :@"DeviceDiscOff",
                                                                 @"DevInfo":@{
                                                                         @"UUID":[cbUUID UUIDString],
                                                                         @"NAME":name,
                                                                         @"CONNECTABLE":params[@"ADV"][@"kCBAdvDataIsConnectable"],
                                                                         @"TXPWR":params[@"ADV"][@"kCBAdvDataTxPowerLevel"],
                                                                         @"RSSI":params[@"RSSI"]
                                                                         },
                                                                 }];
}

// This member function is called when the device is discovered and
// connected or is disconnected. This function is called before
// Device:allProfilesReady:.
- (void) Device:(BLEDevice*)d switchOn:(BOOL)flag
{
    //
    // Receive notification of device status change
    //
    
    device = (DataExchangerDevice*)d;
    
    NSUUID* devUUID = [[NSUUID alloc] initWithUUIDString:[d.devUUID UUIDString]];

    if( flag == NO )
    {
        //
        // Device is disconnected.
        //
 
        connectedDevices[devUUID] = nil;
        activeDevices[devUUID] = nil;

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

        connectedDevices[devUUID] = d;
        
        // This is to ensure the active device stored is the same device here
        activeDevices[devUUID] = d;

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
