//
//  DataExchangerDevice.m
//  BLETestApp
//
//  Created by Ming Leung on 12-12-12.
//  Copyright (c) 2012 GT-Tronics HK Ltd. All rights reserved.
//
//  $Rev: 419 $
//


#import "DataExchangerDevice.h"
#import "DataExchangerProfile.h"

@interface DataExchangerDevice()

@property id<DataExchangerDeviceAppDelegateProtocol> discoveryDelegate;

@end

@implementation DataExchangerDevice

@synthesize discoveryDelegate;

+ (DataExchangerDevice*) deviceWithAppDelegate:(id<DataExchangerDeviceAppDelegateProtocol>)delegate
{
    DataExchangerDevice* dev = [[DataExchangerDevice alloc] initWithAppDelegate:delegate];
    if( dev )
    {
        dev.discoveryDelegate = delegate;
    }
    return dev;
}

- (NSInteger) evaluateDeviceMatchingScoreBasedOnAdvertisingData:(NSDictionary *)adv rssi:(NSNumber *)rssi deviceName:(NSString *)name
{
    // Insert your code here to make decision whether you should connect or not.
    //
    // - The return value is the score used by the controller to determine
    //   which registered device to be used for the rest of the discovering process.
    //   The implementation of this method should use the data provided in the
    //   adversting dictionary, rssi, and discovered device name to determine
    //   the score. If the discovered device is absolutely not matched, return -1.
    //   If discovered device is matched but should be choosen based on BLEController
    //   policy, return 0. If discovered device is matched should be choosen based on
    //   user defined policy, return any number between 1 to 100. In this case,
    //   the highest score will be picked.
    //
    // - the example here check couple things:
    //   1/ make sure the advertisement contains DataExchanger Service UUID
    //   2/ rssi is larger -45dbM
    //
    // - For a list of advertisementData keys, see {CBAdvertisementDataLocalNameKey} and other similar
    //   constants in CBAdvertisementData.h
    //   - you can hold the Command key and move the mouse over {CBAdvertisementDataLocalNameKey} to see
    //     the dclaration.
    //
    
    NSArray* cuuids = [adv objectForKey:CBAdvertisementDataServiceUUIDsKey];
    BOOL matched = NO;
    
    NSLog(@"%@", [(CBUUID*)[cuuids firstObject] UUIDString]);
    for( CBUUID* cuuid in cuuids )
    {
        if( [cuuid isEqual:[CBUUID UUIDWithString:kDXServiceUUID]] )
        {
            matched = YES;
        }
    }
    
    if( matched == NO )
    {
        return -1;
    }
    
    NSLog(@"INFO: Peripheral[%@] discovered [RSSI=%@]", name, rssi);
#if 1
    if ( [rssi floatValue] > 0 ||    // filter some bogus value sometime received from iOS
         [rssi floatValue] < -45 )
    {
        return -1;
    }
#endif
    
#if 0
    dispatch_async(dispatch_get_main_queue(), ^{
        [discoveryDelegate Device:self active:YES parameters:@{@"RSSI"];
    });
#endif
         
    return 0;
}


- (BOOL) sendData:(NSData*)data
{
    if( self.state != BLE_DEVICE_CONNECTED )
    {
        return NO;
    }
    
    NSSet* profiles = [self listRegisteredProfile];
    
    for( BLEProfile* profile in profiles )
    {
        if( [profile isMemberOfClass:[DataExchangerProfile class]] )
        {
            return [(DataExchangerProfile*)profile sendTx:data];
        }
    }
    return NO;
}

- (BOOL) sendCmd:(NSData*)data
{
    if( self.state != BLE_DEVICE_CONNECTED )
    {
        return NO;
    }
    
    NSSet* profiles = [self listRegisteredProfile];
    
    for( BLEProfile* profile in profiles )
    {
        if( [profile isMemberOfClass:[DataExchangerProfile class]] )
        {
            return [(DataExchangerProfile*)profile sendTx2:data];
        }
    }
    return NO;
}

- (BOOL) enableTxCreditNotification:(BOOL)enabled
{
    if( self.state != BLE_DEVICE_CONNECTED )
    {
        return NO;
    }
    
    NSSet* profiles = [self listRegisteredProfile];
    
    for( BLEProfile* profile in profiles )
    {
        if( [profile isMemberOfClass:[DataExchangerProfile class]] )
        {
            return [(DataExchangerProfile*)profile enableTxCreditNotification:enabled];
        }
    }
    return NO;
}

- (BOOL) readTxCredit
{
    if( self.state != BLE_DEVICE_CONNECTED )
    {
        return NO;
    }
    
    NSSet* profiles = [self listRegisteredProfile];
    
    for( BLEProfile* profile in profiles )
    {
        if( [profile isMemberOfClass:[DataExchangerProfile class]] )
        {
            return [(DataExchangerProfile*)profile readTxCredit];
        }
    }
    
    return NO;
}

- (BOOL) writeTxCreditReportLoopCount:(uint32_t)count
{
    if( self.state != BLE_DEVICE_CONNECTED )
    {
        return NO;
    }
    
    NSSet* profiles = [self listRegisteredProfile];
    
    for( BLEProfile* profile in profiles )
    {
        if( [profile isMemberOfClass:[DataExchangerProfile class]] )
        {
            return [(DataExchangerProfile*)profile writeTxCreditReportLoopCount:count];
        }
    }
    
    return NO;
}

@end
