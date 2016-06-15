//
//  DxAppSC.h
//  DataExchangerApp
//
//  Created by Ming Leung on 2015-09-24.
//  Copyright © 2015 GT-Tronics HK Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DataExchangerDevice.h"
#import "DataExchangerProfileProtocol.h"

@interface DxAppSC : NSObject <DataExchangerDeviceAppDelegateProtocol, DataExchangerProfileProtocol>

@property (nonatomic, assign)   BOOL        enableTxCreditNoti;

+ (DxAppSC*)controller;


- (id) initWithDeviceCount:(NSUInteger)devCount proximityPowerLevel:(float)pwrLevel discoveryActiveTimeout:(NSTimeInterval)timeout;

- (BOOL) isEnabled;

- (void) startScan;
- (void) stopScan;
- (BOOL) isScanning;

- (BOOL) connectDevice:(NSUUID*)uuid;
- (BOOL) disconnectDevice:(NSUUID*)uuid;
- (NSUInteger) connectedDeviceCount;
- (BOOL) isDeviceConnected:(NSUUID*)uuid;
- (BOOL) isDeviceActive:(NSUUID*)uuid;

- (BOOL) sendData:(NSData*)data;
- (BOOL) sendCmd:(NSData*)data;
- (BOOL) readTxCredit;
- (BOOL) writeTxCreditReportLoopCount:(uint32_t)count;

@end
