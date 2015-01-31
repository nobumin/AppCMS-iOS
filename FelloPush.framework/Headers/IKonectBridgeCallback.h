//
//  IKonectCallback.h
//  konect_sdk_ios
//
//  Created by rudo on 2013/05/19.
//  Copyright (c) 2013年 Walrus Design Inc,. All rights reserved.
//

#import <Foundation/Foundation.h>
@class SdkBridgeCallback;

@protocol IKonectBridgeCallback <NSObject>

- (void)callback:(NSString*)type name:(NSString*)name param:(NSString*)param callbackReturnId:(NSString*)callbackReturnId;

@end
