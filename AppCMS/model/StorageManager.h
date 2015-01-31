//
//  StorageManager.h
//  AppCMS
//
//  Created by 長島 伸光 on 2015/01/21.
//  Copyright (c) 2015年 MEAS. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    DOCUMENT,
    TEMPORARY,
    USER_DEFAULTS
} STORAGE_TYPE;


@interface StorageManager : NSObject {
    
}

+ (StorageManager*)buildManager;
- (NSObject*)get:(STORAGE_TYPE)type key:(NSString*)key;
- (void)put:(STORAGE_TYPE)type key:(NSString*)key value:(NSObject*)value;
- (void)remove:(STORAGE_TYPE)type key:(NSString*)key;

@end
