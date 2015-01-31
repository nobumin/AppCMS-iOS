//
//  StorageManager.m
//  AppCMS
//
//  Created by 長島 伸光 on 2015/01/21.
//  Copyright (c) 2015年 MEAS. All rights reserved.
//

#import "StorageManager.h"
#import "CMSAppDelegate.h"

@interface StorageManager() {
    dispatch_semaphore_t semaphore_;
}

@end

static StorageManager *sharedInstance;

@implementation StorageManager

+ (StorageManager*)buildManager
{
    
    static dispatch_once_t once;
    dispatch_once( &once, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
    
}

+ (id)allocWithZone:(NSZone *)zone
{
    __block id ret = nil;
    
    static dispatch_once_t once;
    dispatch_once( &once, ^{
        sharedInstance = [super allocWithZone:zone];
        ret = sharedInstance;
    });
    
    return  ret;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)init
{
    self = [super init];
    if(self) {
        semaphore_ = nil;
    }
    return self;
}

- (NSObject*)get:(STORAGE_TYPE)type key:(NSString*)key
{
    if(type == USER_DEFAULTS) {
        return [App getSetting:key];
    }
    NSObject *result = nil;
    [self lock];
    NSMutableDictionary *dic = [self getStorege:type];
    result = [dic valueForKey:key];
    [self unlock];
    return result;
}

- (void)put:(STORAGE_TYPE)type key:(NSString*)key value:(NSObject*)value
{
    if(type == USER_DEFAULTS) {
        [App setSetting:key value:value];
    }else{
        [self lock];
        NSMutableDictionary *dic = [self getStorege:type];
        [dic setValue:value forKey:key];
        [self saveStorge:dic type:type];
        [self unlock];
    }
}

- (void)remove:(STORAGE_TYPE)type key:(NSString*)key
{
    if(type == USER_DEFAULTS) {
        [App removeSetting:key];
    }else{
        [self lock];
        NSMutableDictionary *dic = [self getStorege:type];
        [dic removeObjectForKey:key];
        [self saveStorge:dic type:type];
        [self unlock];
    }
}

- (NSMutableDictionary*)getStorege:(STORAGE_TYPE)type
{
    return [[NSMutableDictionary alloc] initWithContentsOfFile:[self getStoragePath:type]];
}

- (NSString*)getStoragePath:(STORAGE_TYPE)type
{
    if(type == DOCUMENT) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        return [NSString stringWithFormat:@"%@/storage.dic", [paths objectAtIndex:0]];

    }else if(type == TEMPORARY) {
        return [NSString stringWithFormat:@"%@/storage.dic", NSTemporaryDirectory()];
    }
    return nil;
}

- (void)saveStorge:(NSMutableDictionary*)dic type:(STORAGE_TYPE)type
{
    NSString *path = [self getStoragePath:type];
    [dic writeToFile:path atomically:YES];
}

- (void)lock
{
    if(semaphore_) {
        dispatch_semaphore_wait(semaphore_, DISPATCH_TIME_FOREVER);
    }
    semaphore_ = dispatch_semaphore_create(0);
}

- (void)unlock
{
    dispatch_semaphore_signal(semaphore_);
    semaphore_ = nil;
}

@end
