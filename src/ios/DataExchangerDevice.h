//
//  DataExchangerDevice.h
//  BLETestApp
//
//  Created by Ming Leung on 12-12-12.
//  Copyright (c) 2012 GT-Tronics HK Ltd. All rights reserved.
//
//  $Rev: 419 $
//

#import "BLEDevice.h"

@class DataExchangerDevice;

@protocol DataExchangerDeviceAppDelegateProtocol <BLEDeviceAppDelegateProtocol>

@required

- (void) Device:(DataExchangerDevice*)d active:(BOOL)isActive parameters:(NSDictionary*)params;

@end

@interface DataExchangerDevice : BLEDevice

+ (DataExchangerDevice*) deviceWithAppDelegate:(id<DataExchangerDeviceAppDelegateProtocol>)delegate;

- (BOOL) sendData:(NSData*)data;
- (BOOL) sendCmd:(NSData*)data;
- (BOOL) enableTxCreditNotification:(BOOL)enabled;
- (BOOL) readTxCredit;
- (BOOL) writeTxCreditReportLoopCount:(uint32_t)count;

@end
