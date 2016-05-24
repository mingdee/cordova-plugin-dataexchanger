//
//  DxAppSC.h
//  DataExchangerApp
//
//  Created by Ming Leung on 2015-09-24.
//  Copyright © 2015 GT-Tronics HK Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLEDeviceAppDelegateProtocol.h"
#import "DataExchangerProfileProtocol.h"

@interface DxAppSC : NSObject <BLEDeviceAppDelegateProtocol, DataExchangerProfileProtocol>

@property (nonatomic, assign)   BOOL        enableTxCreditNoti;

+ (DxAppSC*)controller;

- (void) startScan;
- (void) stopScan;

- (bool) connect:(NSUUID*)uuid;
- (bool) disconnect:(NSUUID*)uuid;

- (BOOL) sendData:(NSData*)data;
- (BOOL) sendCmd:(NSData*)data;
- (BOOL) readTxCredit;
- (BOOL) writeTxCreditReportLoopCount:(uint32_t)count;

- (BOOL) isEnabled;
- (BOOL) isConnected;

@end
