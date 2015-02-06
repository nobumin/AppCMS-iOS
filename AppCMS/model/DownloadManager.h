//
//  DownloadManager.h
//  AppCMS
//
//  Created by 長島 伸光 on 2015/01/03.
//  Copyright (c) 2015年 MEAS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Reachability.h"

#define REACHABLE_CHECK_HOSTNAME "google.com"
#define ACCESSABLE_CHECK_URL @"http://google.com"
#define REQUEST_TIMEOUT 30.0
#define UI_LASTUPDATE @"last_ui_update_"
#define MULTIPART_BOUNDALY @"__28gkskm_579fhjsj_"

typedef void(^downloadSucceeded)(NSURL* path);
typedef void(^downloadFailed)(NSError *error, NSURL* path);
typedef void(^updateUI)(BOOL sccess);

typedef enum {
    DOWNLOAD,
    UI_UPDATE,
    DOWNLOAD_CACHE
} CALLBACK_TYPE;

typedef enum {
    CONNECT,
    NOT_CONNECT,
    CONNECT_3G,
    CONNECT_WAIT,
} NETWORK_STATUS;

@protocol backgroundTask <NSObject> //background task instance

@optional
-(void)execTask:(updateUI)succeed;

@end

@interface DownloadManager : NSObject<NSURLSessionDownloadDelegate, ReachabilityDelegate> {
    
}

+ (DownloadManager*)buildManager;
- (NETWORK_STATUS)checkNetwork;
//background task
- (void)addBackgroundTask:(NSString*)key task:(id<backgroundTask>)task;
- (void)removeBackgroundTask:(NSString*)key;
- (void)downloadBackground:(updateUI)succeed;
//ON Progress
- (void)download:(NSURL*)url succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed;
- (void)downloadUIPackage:(updateUI)update;
- (void)downloadWithCache:(NSURL*)url cache:(NSURL*)cacheURL succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed;
- (void)download:(NSURL*)url datas:(NSDictionary*)datas succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed;
- (void)downloadWithCache:(NSURL*)url datas:(NSDictionary*)datas cache:(NSURL*)cacheURL succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed;
//NO Progress
- (void)offProgressDownload:(NSURL*)url succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed;
- (void)offProgressDownloadUIPackage:(updateUI)update;
- (void)offProgressDownloadWithCache:(NSURL*)url cache:(NSURL*)cacheURL succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed;
- (void)offProgressDownload:(NSURL*)url datas:(NSDictionary*)datas succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed;
- (void)offProgressDownloadWithCache:(NSURL*)url datas:(NSDictionary*)datas cache:(NSURL*)cacheURL succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed;

@end

@interface CallbackObject : NSObject {
    
}

- (void)setCallback:(downloadSucceeded)succeed failed:(downloadFailed)failed;
- (void)setCallback:(downloadSucceeded)succeed failed:(downloadFailed)failed cache:(NSURL*)cacheURL;
- (void)setCallback:(updateUI)callback;
- (downloadSucceeded)getSucceed;
- (downloadFailed)getFailed;
- (updateUI)getUpdateUI;
- (NSURL*)getCachePath;
- (CALLBACK_TYPE)getType;

@end
