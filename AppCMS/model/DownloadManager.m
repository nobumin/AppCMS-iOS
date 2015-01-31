//
//  DownloadManager.m
//  AppCMS
//
//  Created by 長島 伸光 on 2015/01/03.
//  Copyright (c) 2015年 MEAS. All rights reserved.
//

#import "DownloadManager.h"
#import "CMSAppDelegate.h"
#import <AFNetworking/AFNetworking.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#import <SSZipArchive/SSZipArchive.h>

@interface DownloadManager() {
    NSMutableDictionary *downloadMap_;
    NSMutableDictionary *onlineWaitMap_;
    NETWORK_STATUS status_;
}

@end

static DownloadManager *sharedInstance;

@implementation DownloadManager

+ (DownloadManager*)buildManager
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
        if(!downloadMap_) {
            downloadMap_ = [[NSMutableDictionary alloc] initWithCapacity:0];
        }
        if(!onlineWaitMap_) {
            onlineWaitMap_ = [[NSMutableDictionary alloc] initWithCapacity:0];
        }
    }
    return self;
}

- (NETWORK_STATUS)checkNetwork
{
    status_ = CONNECT_WAIT;
    if([NSRunLoop currentRunLoop] == [NSRunLoop mainRunLoop]) {
        [self checkNetworkRun];
    }else{
        NSMutableArray *modeArray = [[NSMutableArray alloc] initWithObjects:NSDefaultRunLoopMode, nil];
        [[NSRunLoop mainRunLoop] performSelector:@selector(checkNetworkRun) target:self argument:nil order:0 modes:modeArray];
        while (status_ == CONNECT_WAIT) {
            [NSThread sleepForTimeInterval:0.02];
        }
        [modeArray removeAllObjects];
        modeArray = nil;
    }
    return status_;
}

- (void)checkNetworkRun
{
    Reachability *reachability = [Reachability buildObject];
    if([reachability waitReachable]) {
        status_ = NOT_CONNECT;
        return;
    }
    
    //Network configuration check
    SCNetworkReachabilityFlags flags;
    SCNetworkReachabilityRef reachabilityRef;
    reachabilityRef =  SCNetworkReachabilityCreateWithName(NULL, REACHABLE_CHECK_HOSTNAME);
    if(reachabilityRef == NULL) {
        status_ = NOT_CONNECT;
        return;
    }
    BOOL gotFlags = SCNetworkReachabilityGetFlags(reachabilityRef, &flags);
    CFRelease(reachabilityRef);
    BOOL cellConnect = NO;
    
    if (!gotFlags) {
        status_ = NOT_CONNECT;
        return;
    }
    
    BOOL isReachable = flags & kSCNetworkReachabilityFlagsReachable;
    
    BOOL noConnectionRequired = !(flags & kSCNetworkReachabilityFlagsConnectionRequired);
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN)) {
        cellConnect = YES;
        noConnectionRequired = YES;
    }
    
    if(!isReachable || !noConnectionRequired) {
        status_ = NOT_CONNECT;
        return;
    }
    
    status_ = cellConnect ? CONNECT_3G : CONNECT;
    
    return;
}

- (NSURL*)exchangeToLocalCacheURL:(NSURL*)cacheURL
{
    NSString *absPath = [cacheURL absoluteString];
    NSString *path = [cacheURL path];
    NSString *cachePath = [App getConfigSetting:@"cachePath"];
    NSString *baseURL = [absPath substringToIndex:[absPath rangeOfString:path].location];
    
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@/%@", baseURL, cachePath, path]];
}

- (void)download:(NSURL*)url succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed
{
    [self download:url succeed:succeed failed:false onProgress:YES];
}

- (void)downloadUIPackage:(updateUI)update
{
    [self downloadUIPackage:update onProgress:YES];
}

- (void)downloadWithCache:(NSURL*)url cache:(NSURL*)cacheURL succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed
{
    [self downloadWithCache:url cache:cacheURL succeed:succeed failed:failed onProgress:YES];
}

- (void)download:(NSURL*)url datas:(NSDictionary*)datas succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed
{
    [self download:url datas:datas succeed:succeed failed:failed onProgress:YES];
}

- (void)downloadWithCache:(NSURL*)url datas:(NSDictionary*)datas cache:(NSURL*)cacheURL succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed
{
    [self downloadWithCache:url datas:datas cache:cacheURL succeed:succeed failed:failed onProgress:YES];
}

- (void)offProgressDownload:(NSURL*)url succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed
{
    [self download:url succeed:succeed failed:false onProgress:NO];
}

- (void)offProgressDownloadUIPackage:(updateUI)update
{
    [self downloadUIPackage:update onProgress:NO];
}

- (void)offProgressDownloadWithCache:(NSURL*)url cache:(NSURL*)cacheURL succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed
{
    [self downloadWithCache:url cache:cacheURL succeed:succeed failed:failed onProgress:NO];
}

- (void)offProgressDownload:(NSURL*)url datas:(NSDictionary*)datas succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed
{
    [self download:url datas:datas succeed:succeed failed:failed onProgress:NO];
}

- (void)offProgressDownloadWithCache:(NSURL*)url datas:(NSDictionary*)datas cache:(NSURL*)cacheURL succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed
{
    [self downloadWithCache:url datas:datas cache:cacheURL succeed:succeed failed:failed onProgress:NO];
}

- (void)download:(NSURL*)url succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed onProgress:(BOOL)onPregress
{
    if(onPregress) {
        [App displayProgress];
    }
    NETWORK_STATUS nstatus = [self checkNetwork];
    if(nstatus != CONNECT && nstatus != CONNECT_3G) {
        NSError *error = [[NSError alloc] initWithDomain:[url absoluteString] code:500
                                                userInfo:@{NSLocalizedDescriptionKey:[NSHTTPURLResponse localizedStringForStatusCode:500],
                                                           NSLocalizedRecoverySuggestionErrorKey:[NSHTTPURLResponse localizedStringForStatusCode:500]}];
        failed(error, url);
        [App hiddenProgress];
    }else{
        dispatch_queue_t sQueue = dispatch_queue_create("jp.meas.dispatch", NULL);
        dispatch_async(sQueue, ^{
            NSString *identifier = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]];
            NSURLSessionConfiguration *configration = nil;
            if([App isUnderIOS8]) {
                configration = [NSURLSessionConfiguration backgroundSessionConfiguration:identifier];
            }else{
                configration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
            }
            NSURLSession *session = [NSURLSession sessionWithConfiguration:configration delegate:self delegateQueue:nil];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
            [request setTimeoutInterval:REQUEST_TIMEOUT];
            [request setHTTPShouldHandleCookies:YES];
            [request setHTTPMethod:@"GET"];
            NSURLSessionDownloadTask* downloadTask = [session downloadTaskWithRequest:request];
            CallbackObject *callback = [[CallbackObject alloc] init];
            [callback setCallback:succeed failed:failed];
            [downloadMap_ setObject:callback forKey:identifier];
            [downloadTask resume];
        });
    }
}

- (void)downloadUIPackage:(updateUI)update onProgress:(BOOL)onPregress
{
    if(onPregress) {
        [App displayProgress];
    }
    NETWORK_STATUS nstatus = [self checkNetwork];
    if(nstatus == CONNECT || nstatus == CONNECT_3G) {
        dispatch_queue_t sQueue = dispatch_queue_create("jp.meas.dispatch", NULL);
        dispatch_async(sQueue, ^{
            NSString *identifier = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]];
            NSURLSessionConfiguration *configration = nil;
            if([App isUnderIOS8]) {
                configration = [NSURLSessionConfiguration backgroundSessionConfiguration:identifier];
            }else{
                configration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
            }
            NSURLSession *session = [NSURLSession sessionWithConfiguration:configration delegate:self delegateQueue:nil];
            NSURL *url = [NSURL URLWithString:[App getConfigSetting:@"UIPackageURL"]];
            NSURLRequest *request = [NSURLRequest requestWithURL:url];
            NSURLSessionDownloadTask* downloadTask = [session downloadTaskWithRequest:request];
            CallbackObject *callback = [[CallbackObject alloc] init];
            [callback setCallback:update];
            [downloadMap_ setObject:callback forKey:identifier];
            [downloadTask resume];
        });
    }else{
        update(NO);
        [App hiddenProgress];
    }
}

- (void)downloadWithCache:(NSURL*)url cache:(NSURL*)cacheURL succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed onProgress:(BOOL)onPregress
{
    if(onPregress) {
        [App displayProgress];
    }
    NETWORK_STATUS nstatus = [self checkNetwork];
    NSURL *cacheURLA = [self exchangeToLocalCacheURL:cacheURL];
    
    if(nstatus != CONNECT && nstatus != CONNECT_3G) {
        NSString *cacheRealPath = [NSString stringWithFormat:@"%@%@", [App cacheRoot], [cacheURL path]];
        NSFileManager *fm = [NSFileManager defaultManager];
        if([fm fileExistsAtPath:cacheRealPath]) {
            succeed(cacheURLA);
        }else{
            CallbackObject *callback = [[CallbackObject alloc] init];
            [callback setCallback:succeed failed:failed cache:cacheURLA];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
            [request setTimeoutInterval:REQUEST_TIMEOUT];
            [request setHTTPShouldHandleCookies:YES];
            [request setHTTPMethod:@"GET"];
            [onlineWaitMap_ setObject:callback forKey:request];
        }
        [App hiddenProgress];
    }else{
        dispatch_queue_t sQueue = dispatch_queue_create("jp.meas.dispatch", NULL);
        dispatch_async(sQueue, ^{
            NSString *identifier = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]];
            NSURLSessionConfiguration *configration = nil;
            if([App isUnderIOS8]) {
                configration = [NSURLSessionConfiguration backgroundSessionConfiguration:identifier];
            }else{
                configration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
            }
            NSURLSession *session = [NSURLSession sessionWithConfiguration:configration delegate:self delegateQueue:nil];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
            [request setTimeoutInterval:REQUEST_TIMEOUT];
            [request setHTTPShouldHandleCookies:YES];
            [request setHTTPMethod:@"GET"];
            NSURLSessionDownloadTask* downloadTask = [session downloadTaskWithRequest:request];
            CallbackObject *callback = [[CallbackObject alloc] init];
            [callback setCallback:succeed failed:failed cache:cacheURLA];
            [downloadMap_ setObject:callback forKey:identifier];
            [downloadTask resume];
        });
    }
}

- (void)download:(NSURL*)url datas:(NSDictionary*)datas succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed onProgress:(BOOL)onPregress
{
    if(onPregress) {
        [App displayProgress];
    }
    NETWORK_STATUS nstatus = [self checkNetwork];
    if(nstatus != CONNECT && nstatus != CONNECT_3G) {
        NSError *error = [[NSError alloc] initWithDomain:[url absoluteString] code:500
                                                userInfo:@{NSLocalizedDescriptionKey:[NSHTTPURLResponse localizedStringForStatusCode:500],
                                                           NSLocalizedRecoverySuggestionErrorKey:[NSHTTPURLResponse localizedStringForStatusCode:500]}];
        failed(error, url);
        [App hiddenProgress];
    }else{
        dispatch_queue_t sQueue = dispatch_queue_create("jp.meas.dispatch", NULL);
        dispatch_async(sQueue, ^{
            NSString *identifier = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]];
            NSURLSessionConfiguration *configration = nil;
            if([App isUnderIOS8]) {
                configration = [NSURLSessionConfiguration backgroundSessionConfiguration:identifier];
            }else{
                configration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
            }
            NSURLSession *session = [NSURLSession sessionWithConfiguration:configration delegate:self delegateQueue:nil];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            [request setHTTPMethod:@"POST"];
            if(datas) {
                NSMutableData *sendData = [NSMutableData data];
                NSArray *keys = [datas allKeys];
                for(NSString *key in keys) {
                    [sendData appendData:[[NSString stringWithFormat:@"--%@\r\n", MULTIPART_BOUNDALY] dataUsingEncoding:NSUTF8StringEncoding]];
                    NSObject *data = [datas valueForKey:key];
                    if([data isKindOfClass:[NSData class]]) {
                        [sendData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data;"] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"name=\"%@\";", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"filename=\"%@.jpg\"\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"Content-Type: image/jpeg\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:(NSData*)data];
                        [sendData appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
                    }else if([data isKindOfClass:[UIImage class]]) {
                        [sendData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data;"] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"name=\"%@\";", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"filename=\"%@.png\"\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"Content-Type: image/png\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:UIImagePNGRepresentation((UIImage*)data)];
                        [sendData appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
                    }else{
                        [sendData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data;"] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"%@\r\n", data] dataUsingEncoding:NSUTF8StringEncoding]];
                    }
                    
                }
                [sendData appendData:[[NSString stringWithFormat:@"--%@--\r\n", MULTIPART_BOUNDALY] dataUsingEncoding:NSUTF8StringEncoding]];
                [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
                [request setTimeoutInterval:REQUEST_TIMEOUT];
                [request setHTTPShouldHandleCookies:YES];
                [request setHTTPBody:sendData];
            }
            NSURLSessionDownloadTask* downloadTask = [session downloadTaskWithRequest:request];
            CallbackObject *callback = [[CallbackObject alloc] init];
            [callback setCallback:succeed failed:failed];
            [downloadMap_ setObject:callback forKey:identifier];
            [downloadTask resume];
        });
    }
}

- (void)downloadWithCache:(NSURL*)url datas:(NSDictionary*)datas cache:(NSURL*)cacheURL
                  succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed onProgress:(BOOL)onPregress
{
    if(onPregress) {
        [App displayProgress];
    }
    NETWORK_STATUS nstatus = [self checkNetwork];
    NSURL *cacheURLA = [self exchangeToLocalCacheURL:cacheURL];
    
    if(nstatus != CONNECT && nstatus != CONNECT_3G) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *cacheRealPath = [NSString stringWithFormat:@"%@%@", [App cacheRoot], [cacheURL path]];
        if([fm fileExistsAtPath:cacheRealPath]) {
            succeed(cacheURLA);
            [App hiddenProgress];
        }else{
            CallbackObject *callback = [[CallbackObject alloc] init];
            [callback setCallback:succeed failed:failed cache:cacheURLA];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            [request setHTTPMethod:@"POST"];
            if(datas) {
                NSMutableData *sendData = [NSMutableData data];
                NSArray *keys = [datas allKeys];
                for(NSString *key in keys) {
                    [sendData appendData:[[NSString stringWithFormat:@"--%@\r\n", MULTIPART_BOUNDALY] dataUsingEncoding:NSUTF8StringEncoding]];
                    NSObject *data = [datas valueForKey:key];
                    if([data isKindOfClass:[NSData class]]) {
                        [sendData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data;"] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"name=\"%@\";", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"filename=\"%@.jpg\"\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"Content-Type: image/jpeg\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:(NSData*)data];
                        [sendData appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
                    }else if([data isKindOfClass:[UIImage class]]) {
                        [sendData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data;"] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"name=\"%@\";", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"filename=\"%@.png\"\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"Content-Type: image/png\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:UIImagePNGRepresentation((UIImage*)data)];
                        [sendData appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
                    }else{
                        [sendData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data;"] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"%@\r\n", data] dataUsingEncoding:NSUTF8StringEncoding]];
                    }
                    
                }
                [sendData appendData:[[NSString stringWithFormat:@"--%@--\r\n", MULTIPART_BOUNDALY] dataUsingEncoding:NSUTF8StringEncoding]];
                [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
                [request setTimeoutInterval:REQUEST_TIMEOUT];
                [request setHTTPShouldHandleCookies:YES];
                [request setHTTPBody:sendData];
            }
            [onlineWaitMap_ setObject:callback forKey:request];
        }
    }else{
        dispatch_queue_t sQueue = dispatch_queue_create("jp.meas.dispatch", NULL);
        dispatch_async(sQueue, ^{
            NSString *identifier = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]];
            NSURLSessionConfiguration *configration = nil;
            if([App isUnderIOS8]) {
                configration = [NSURLSessionConfiguration backgroundSessionConfiguration:identifier];
            }else{
                configration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
            }
            NSURLSession *session = [NSURLSession sessionWithConfiguration:configration delegate:self delegateQueue:nil];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            [request setHTTPMethod:@"POST"];
            if(datas) {
                NSMutableData *sendData = [NSMutableData data];
                NSArray *keys = [datas allKeys];
                for(NSString *key in keys) {
                    [sendData appendData:[[NSString stringWithFormat:@"--%@\r\n", MULTIPART_BOUNDALY] dataUsingEncoding:NSUTF8StringEncoding]];
                    NSObject *data = [datas valueForKey:key];
                    if([data isKindOfClass:[NSData class]]) {
                        [sendData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data;"] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"name=\"%@\";", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"filename=\"%@.jpg\"\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"Content-Type: image/jpeg\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:(NSData*)data];
                        [sendData appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
                    }else if([data isKindOfClass:[UIImage class]]) {
                        [sendData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data;"] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"name=\"%@\";", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"filename=\"%@.png\"\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"Content-Type: image/png\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:UIImagePNGRepresentation((UIImage*)data)];
                        [sendData appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
                    }else{
                        [sendData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data;"] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [sendData appendData:[[NSString stringWithFormat:@"%@\r\n", data] dataUsingEncoding:NSUTF8StringEncoding]];
                    }
                    
                }
                [sendData appendData:[[NSString stringWithFormat:@"--%@--\r\n", MULTIPART_BOUNDALY] dataUsingEncoding:NSUTF8StringEncoding]];
                [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
                [request setTimeoutInterval:REQUEST_TIMEOUT];
                [request setHTTPShouldHandleCookies:YES];
                [request setHTTPBody:sendData];
            }
            NSURLSessionDownloadTask* downloadTask = [session downloadTaskWithRequest:request];
            CallbackObject *callback = [[CallbackObject alloc] init];
            [callback setCallback:succeed failed:failed cache:cacheURLA];
            [downloadMap_ setObject:callback forKey:identifier];
            [downloadTask resume];
        });
    }
}


#pragma ReachabilityDelegate protocol

- (void)reachNetwork
{
    if(onlineWaitMap_) {
        NSArray *keys = [onlineWaitMap_ allKeys];
        for(NSMutableURLRequest *request in keys) {
            dispatch_queue_t sQueue = dispatch_queue_create("jp.meas.dispatch", NULL);
            dispatch_async(sQueue, ^{
                NSString *identifier = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]];
                NSURLSessionConfiguration *configration = nil;
                if([App isUnderIOS8]) {
                    configration = [NSURLSessionConfiguration backgroundSessionConfiguration:identifier];
                }else{
                    configration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
                }
                NSURLSession *session = [NSURLSession sessionWithConfiguration:configration delegate:self delegateQueue:nil];
                NSURLSessionDownloadTask* downloadTask = [session downloadTaskWithRequest:request];
                CallbackObject *callback = [onlineWaitMap_ objectForKey:request];
                [downloadMap_ setObject:callback forKey:identifier];
                [downloadTask resume];
            });
        }
    }
    [onlineWaitMap_ removeAllObjects];
}

#pragma NSURLSessionDownloadDelegate protocol

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    CallbackObject *callback = [downloadMap_ objectForKey:session.configuration.identifier];
    NSHTTPURLResponse *response = (NSHTTPURLResponse*)task.response;
    if(response.statusCode != 200) {
        if(callback) {
            downloadFailed failed = [callback getFailed];
            if(failed) {
                failed(error, response.URL);
            }
        }
    }
    [App hiddenProgress];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location;
{
    //downloadファイルパス
    CallbackObject *callback = [downloadMap_ objectForKey:session.configuration.identifier];
    if(callback) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse*)downloadTask.response;
        if([callback getType] == DOWNLOAD) {
            if(response.statusCode == 200) {
                downloadSucceeded succeed = [callback getSucceed];
                succeed(location);
            }else{
                downloadFailed failed = [callback getFailed];
                NSError *error = [[NSError alloc] initWithDomain:[response.URL absoluteString] code:response.statusCode
                                                        userInfo:@{NSLocalizedDescriptionKey:[NSHTTPURLResponse localizedStringForStatusCode:response.statusCode],
                                                                   NSLocalizedRecoverySuggestionErrorKey:[NSHTTPURLResponse localizedStringForStatusCode:response.statusCode]}];
                failed(error, response.URL);
            }
        }else if([callback getType] == DOWNLOAD_CACHE) {
            if(response.statusCode == 200) {
                NSString *cacheRealPath = [NSString stringWithFormat:@"%@%@", [App cacheRoot], [[callback getCachePath] path]];
                if([[response.MIMEType lowercaseString] rangeOfString:@"zip"].location != NSNotFound) {
                    if([SSZipArchive unzipFileAtPath:[location path] toDestination:cacheRealPath]) {
                        downloadSucceeded succeed = [callback getSucceed];
                        succeed([callback getCachePath]);
                    }else{
                        downloadFailed failed = [callback getFailed];
                        NSError *error = [[NSError alloc] initWithDomain:[[callback getCachePath] absoluteString] code:500
                                                                userInfo:@{NSLocalizedDescriptionKey:[NSHTTPURLResponse localizedStringForStatusCode:500],
                                                                           NSLocalizedRecoverySuggestionErrorKey:[NSHTTPURLResponse localizedStringForStatusCode:500]}];
                        failed(error, response.URL);
                    }
                }else{
                    NSError *error = nil;
                    NSFileManager *fm = [NSFileManager defaultManager];
                    [fm copyItemAtPath:[location absoluteString] toPath:cacheRealPath error:&error];
                    if(error) {
                        downloadFailed failed = [callback getFailed];
                        failed(error, response.URL);
                    }
                }
            }else{
                downloadFailed failed = [callback getFailed];
                NSError *error = [[NSError alloc] initWithDomain:[response.URL absoluteString] code:response.statusCode
                                                        userInfo:@{NSLocalizedDescriptionKey:[NSHTTPURLResponse localizedStringForStatusCode:response.statusCode],
                                                                   NSLocalizedRecoverySuggestionErrorKey:[NSHTTPURLResponse localizedStringForStatusCode:response.statusCode]}];
                failed(error, response.URL);
            }
        }else if([callback getType] == UI_UPDATE) {
            updateUI succeed = [callback getUpdateUI];
            BOOL call = NO;
            if(response.statusCode == 200) {
                if([self isNewUIPack:response.allHeaderFields]) {
                    if([[response.MIMEType lowercaseString] rangeOfString:@"zip"].location != NSNotFound) {
                        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                        NSString *documentsRootTemp = [NSString stringWithFormat:@"%@/htdocs_tmp/", [paths objectAtIndex:0]];

                        //キャッシュファイルをバックアップ
                        NSString *cacheBackPath = [NSString stringWithFormat:@"%@/%@", [paths objectAtIndex:0], [App getConfigSetting:@"cachePath"]];
                        NSFileManager *fm = [NSFileManager defaultManager];
                        if([fm fileExistsAtPath:[App cacheRoot]]) {
                            [fm moveItemAtPath:[App cacheRoot] toPath:[paths objectAtIndex:0] error:nil];
                        }
                        if([SSZipArchive unzipFileAtPath:[location path] toDestination:documentsRootTemp]) {
                            NSString *documentsRoot = [App documentRoot];
                            NSFileManager *fm = [NSFileManager defaultManager];
                            NSError *error = nil;
                            [fm removeItemAtPath:documentsRoot error:&error];
                            [fm moveItemAtPath:documentsRootTemp toPath:documentsRoot error:&error];
                            call = YES;
                            //キャッシュファイルをリストア
                            if([fm fileExistsAtPath:cacheBackPath]) {
                                [fm moveItemAtPath:cacheBackPath toPath:[App documentRoot] error:nil];
                            }
                        }
                    }
                }
            }
            if(call) {
                succeed(YES);
            }else{
                succeed(NO);
            }
        }
        [downloadMap_ removeObjectForKey:session.configuration.identifier];
    }
    [App hiddenProgress];
}

- (BOOL)isNewUIPack:(NSDictionary*)header
{
    NSString *lastMod = [header objectForKey:@"Last-Modified"];
    NSString *lastUpdate = (NSString*)[App getSetting:UI_LASTUPDATE];
    if(lastUpdate && [lastUpdate isEqualToString:lastMod]) {
        return NO;
    }
    [App setSetting:UI_LASTUPDATE value:lastMod];
    return YES;
}

@end

@interface CallbackObject() {
    downloadSucceeded succeed_;
    downloadFailed failed_;
    updateUI uiupdate_;
    NSURL *cachePath_;
    CALLBACK_TYPE type_;
}

@end

@implementation CallbackObject

- (void)setCallback:(downloadSucceeded)succeed failed:(downloadFailed)failed
{
    succeed_ = succeed;
    failed_ = failed;
    type_ = DOWNLOAD;
}

- (void)setCallback:(downloadSucceeded)succeed failed:(downloadFailed)failed cache:(NSURL*)cacheURL
{
    succeed_ = succeed;
    failed_ = failed;
    cachePath_ = [NSURL URLWithString:[cacheURL absoluteString]];
    type_ = DOWNLOAD_CACHE;
}

- (void)setCallback:(updateUI)callback
{
    uiupdate_ = callback;
    type_ = UI_UPDATE;
}

- (downloadSucceeded)getSucceed
{
    return succeed_;
}

- (downloadFailed)getFailed
{
    return failed_;
}

- (updateUI)getUpdateUI
{
    return uiupdate_;
}

- (NSURL*)getCachePath
{
    return cachePath_;
}

- (CALLBACK_TYPE)getType
{
    return type_;
}

@end
