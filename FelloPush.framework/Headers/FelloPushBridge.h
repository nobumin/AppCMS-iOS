//
//  KonectBridge.h
//  konect_sdk_ios
//
//  Created by rudo on 2013/05/19.
//  Copyright (c) 2013年 Walrus Design Inc,. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol IKonectBridgeCallback;

@interface FelloPushBridge : NSObject

+ (void)ensureBridges;
+ (void)setCallback:(NSObject<IKonectBridgeCallback>*)callback;
+ (NSString*)execute:(NSString*)type name:(NSString*)name param:(NSString*)param;
+ (void)callbackReturn:(NSString*)callbackReturnId param:(NSString*)param;

@end
