//
//  KonectAuthenticationCode.h
//  konect_sdk_ios
//
//  Created by rudo on 2013/03/08.
//  Copyright (c) 2013年 Unicon PTE Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol KonectAuthenticationCode

@property (strong, nonatomic) NSString *code;
@property (strong, nonatomic) NSString *state;
@property (strong, nonatomic) NSString *flo_nonce;
@property (strong, nonatomic) NSString *timestamp;

@end
