//
//  ViewController.m
//  AppCMS
//
//  Created by 長島 伸光 on 2014/12/31.
//  Copyright (c) 2014年 MEAS. All rights reserved.
//

#import "CMSViewController.h"
#import "StorageManager.h"
#import "DownloadManager.h"
#import "CameraViewController.h"
#import <CocoaHTTPServer/HTTPServer.h>

@interface CMSViewController () {
    HTTPServer *httpServer_;
}

@end

@implementation CMSViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    for (id subview in webView_.subviews) {
        if ([[subview class] isSubclassOfClass: [UIScrollView class]]) {
            ((UIScrollView *)subview).bounces = NO;
        }
    }
    httpServer_ = [[HTTPServer alloc] init];
    [self startHttpServer:0];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)startHttpServer:(int)retry
{
    int port = SERVER_PORT+retry;
    httpServer_.port = port;
    [httpServer_ stop];
    httpServer_.documentRoot = [App documentRoot];
    NSError *error;
    if(![httpServer_ start:&error]) {
        NSLog(@"Error launch http server(%d) : %@", port, error);
        if(retry < 10) {
            [self startHttpServer:retry+1];
        }else{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"ERROR" message:[error localizedDescription] delegate:self
                                                  cancelButtonTitle:@"CLOSE" otherButtonTitles:nil];
            [alert show];
        }
    }else{
        [webView_ loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/index.html", port]]]];
        webView_.allowsInlineMediaPlayback = YES;
        webView_.delegate = self;
    }
}

- (NSDictionary*)parseQuery:(NSString*)query
{
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:0];
    NSArray *params = [query componentsSeparatedByString:@"&"];
    for(NSString *param in params) {
        NSArray *keyvalue = [param componentsSeparatedByString:@"="];
        NSString *key = [keyvalue objectAtIndex:0];
        NSString *value = [keyvalue objectAtIndex:1];
        [result setValue:value forKey:key];
    }
    return result;
}

- (void) evaluatingJavaScript:(NSString*)script
{
    [webView_ stringByEvaluatingJavaScriptFromString:script];
}

- (NSUInteger)supportedInterfaceOrientations
{
    if([App isiPhone]) {
        return UIInterfaceOrientationMaskPortrait;
    }
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

#pragma mark UIWebViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *url = [request URL];
    NSString *scheme = [url scheme];
    NSString *cmd = [[url host] lowercaseString];
    // host:コマンド
    // [[url pathComponents] objectAtIndex:1]:サブコマンド
    // [[url pathComponents] objectAtIndex:2]:ストレージKey
    // [[url pathComponents] objectAtIndex:3]:ストレージValue
    // lastPathComponent:JSコールバック用ハッシュ
    // query:URL、Cache URL、
   
    if ([scheme isEqualToString:@"appcms"]) {
        NSString *query = [[url query] lowercaseString];
        if([cmd isEqualToString:@"appstore"]) {
            // AppStoreを開く
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/jp/app/%@&mt=8", query]];
            [[UIApplication sharedApplication] openURL:url];
        } else if([cmd isEqualToString:@"document.storage"]) {
            NSString *subCmd = [[[url pathComponents] objectAtIndex:1] lowercaseString];
            StorageManager *sm = [StorageManager buildManager];
            if([subCmd isEqualToString:@"get"]) {
                NSString *key = [[[url pathComponents] objectAtIndex:2] lowercaseString];
                NSString *hashForJsCallback = [url lastPathComponent];
                NSObject *value = [sm get:DOCUMENT key:key];
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true, '%@')", hashForJsCallback, value]];
            } else if([subCmd isEqualToString:@"put"]) {
                NSString *key = [[[url pathComponents] objectAtIndex:2] lowercaseString];
                NSString *value = [[[url pathComponents] objectAtIndex:3] lowercaseString];
                NSString *hashForJsCallback = [url lastPathComponent];
                [sm put:DOCUMENT key:key value:value];
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true)", hashForJsCallback]];
            } else if([subCmd isEqualToString:@"delete"]) {
                NSString *key = [[[url pathComponents] objectAtIndex:2] lowercaseString];
                NSString *hashForJsCallback = [url lastPathComponent];
                [sm remove:DOCUMENT key:key];
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true)", hashForJsCallback]];
            }
        } else if([cmd isEqualToString:@"temp.storage"]) {
            NSString *subCmd = [[[url pathComponents] objectAtIndex:1] lowercaseString];
            StorageManager *sm = [StorageManager buildManager];
            if([subCmd isEqualToString:@"get"]) {
                NSString *key = [[[url pathComponents] objectAtIndex:2] lowercaseString];
                NSString *hashForJsCallback = [url lastPathComponent];
                NSObject *value = [sm get:TEMPORARY key:key];
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true, '%@')", hashForJsCallback, value]];
            } else if([subCmd isEqualToString:@"put"]) {
                NSString *key = [[[url pathComponents] objectAtIndex:2] lowercaseString];
                NSString *value = [[[url pathComponents] objectAtIndex:3] lowercaseString];
                NSString *hashForJsCallback = [url lastPathComponent];
                [sm put:TEMPORARY key:key value:value];
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true)", hashForJsCallback]];
            } else if([subCmd isEqualToString:@"delete"]) {
                NSString *key = [[[url pathComponents] objectAtIndex:2] lowercaseString];
                NSString *hashForJsCallback = [url lastPathComponent];
                [sm remove:TEMPORARY key:key];
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true)", hashForJsCallback]];
            }
        } else if([cmd isEqualToString:@"user.default"]) {
            NSString *subCmd = [[[url pathComponents] objectAtIndex:1] lowercaseString];
            StorageManager *sm = [StorageManager buildManager];
            if([subCmd isEqualToString:@"get"]) {
                NSString *key = [[[url pathComponents] objectAtIndex:2] lowercaseString];
                NSString *hashForJsCallback = [url lastPathComponent];
                NSObject *value = [sm get:USER_DEFAULTS key:key];
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true, '%@')", hashForJsCallback, value]];
            } else if([subCmd isEqualToString:@"put"]) {
                NSString *key = [[[url pathComponents] objectAtIndex:2] lowercaseString];
                NSString *value = [[[url pathComponents] objectAtIndex:3] lowercaseString];
                NSString *hashForJsCallback = [url lastPathComponent];
                [sm put:USER_DEFAULTS key:key value:value];
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true)", hashForJsCallback]];
            } else if([subCmd isEqualToString:@"delete"]) {
                NSString *key = [[[url pathComponents] objectAtIndex:2] lowercaseString];
                NSString *hashForJsCallback = [url lastPathComponent];
                [sm remove:USER_DEFAULTS key:key];
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true)", hashForJsCallback]];
            }
        }
        return NO;
    }else if ([scheme isEqualToString:@"cacheurl"] || [scheme isEqualToString:@"ncacheurl"]) {
        NSString *hashForJsCallback = [url lastPathComponent];
        NSDictionary *keyValues = [self parseQuery:[url query]];
        NSURL *path = [NSURL URLWithString:[[keyValues valueForKey:@"url"] stringByRemovingPercentEncoding]];
        NSURL *cache = [NSURL URLWithString:[[keyValues valueForKey:@"cache"] stringByRemovingPercentEncoding]];
        DownloadManager *dm = [DownloadManager buildManager];
        if([scheme hasPrefix:@"n"]) {
            [dm offProgressDownloadWithCache:path cache:cache succeed:^(NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true, '%@')", hashForJsCallback, [path absoluteString]]];
            } failed:^(NSError *error, NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', false, '%@', '%@')",
                                            hashForJsCallback, [path absoluteString], [error localizedDescription]]];
            }];
        }else{
            [dm downloadWithCache:path cache:cache succeed:^(NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true, '%@')", hashForJsCallback, [path absoluteString]]];
            } failed:^(NSError *error, NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', false, '%@', '%@')",
                                            hashForJsCallback, [path absoluteString], [error localizedDescription]]];
            }];
        }
    }else if ([scheme isEqualToString:@"immedurl"] || [scheme isEqualToString:@"nimmedurl"]) {
        NSString *hashForJsCallback = [url lastPathComponent];
        NSDictionary *keyValues = [self parseQuery:[url query]];
        NSURL *path = [NSURL URLWithString:[[keyValues valueForKey:@"url"] stringByRemovingPercentEncoding]];
        DownloadManager *dm = [DownloadManager buildManager];
        if([scheme hasPrefix:@"n"]) {
            [dm offProgressDownload:path succeed:^(NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true, ')", hashForJsCallback]];
            } failed:^(NSError *error, NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', false, '%@')",
                                            hashForJsCallback, [error localizedDescription]]];
            }];
        }else{
            [dm download:path succeed:^(NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true, ')", hashForJsCallback]];
            } failed:^(NSError *error, NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', false, '%@')",
                                            hashForJsCallback, [error localizedDescription]]];
            }];
        }
    }else if ([scheme isEqualToString:@"cacheurlpost"] || [scheme isEqualToString:@"ncacheurlpost"]) {
        NSString *hashForJsCallback = [url lastPathComponent];
        NSDictionary *keyValues = [self parseQuery:[url query]];
        NSURL *path = [NSURL URLWithString:[[keyValues valueForKey:@"url"] stringByRemovingPercentEncoding]];
        NSURL *cache = [NSURL URLWithString:[[keyValues valueForKey:@"cache"] stringByRemovingPercentEncoding]];
        NSMutableDictionary *postData = [NSMutableDictionary dictionaryWithDictionary:keyValues];
        [postData removeObjectForKey:@"url"];
        [postData removeObjectForKey:@"cache"];
        DownloadManager *dm = [DownloadManager buildManager];
        if([scheme hasPrefix:@"n"]) {
            [dm offProgressDownloadWithCache:path datas:postData cache:cache succeed:^(NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true, '%@')", hashForJsCallback, [path absoluteString]]];
            } failed:^(NSError *error, NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', false, '%@', '%@')",
                                            hashForJsCallback, [path absoluteString], [error localizedDescription]]];
            }];
        }else{
            [dm downloadWithCache:path datas:postData cache:cache succeed:^(NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true, '%@')", hashForJsCallback, [path absoluteString]]];
            } failed:^(NSError *error, NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', false, '%@', '%@')",
                                            hashForJsCallback, [path absoluteString], [error localizedDescription]]];
            }];
        }
    }else if ([scheme isEqualToString:@"immedurlpost"] || [scheme isEqualToString:@"nimmedurlpost"]) {
        NSString *hashForJsCallback = [url lastPathComponent];
        NSDictionary *keyValues = [self parseQuery:[url query]];
        NSURL *path = [NSURL URLWithString:[[keyValues valueForKey:@"url"] stringByRemovingPercentEncoding]];
        NSMutableDictionary *postData = [NSMutableDictionary dictionaryWithDictionary:keyValues];
        [postData removeObjectForKey:@"url"];
        DownloadManager *dm = [DownloadManager buildManager];
        if([scheme hasPrefix:@"n"]) {
            [dm offProgressDownload:path datas:postData succeed:^(NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true, ')", hashForJsCallback]];
            } failed:^(NSError *error, NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', false, '%@')",
                                            hashForJsCallback, [error localizedDescription]]];
            }];
        }else{
            [dm download:path datas:postData succeed:^(NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true, ')", hashForJsCallback]];
            } failed:^(NSError *error, NSURL *path) {
                [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', false, '%@')",
                                            hashForJsCallback, [error localizedDescription]]];
            }];
        }
    }else if ([scheme isEqualToString:@"imageuploadcache"]) {
        NSString *hashForJsCallback = [url lastPathComponent];
        NSDictionary *keyValues = [self parseQuery:[url query]];
        NSURL *path = [NSURL URLWithString:[[keyValues valueForKey:@"url"] stringByRemovingPercentEncoding]];
        NSURL *cache = [NSURL URLWithString:[[keyValues valueForKey:@"cache"] stringByRemovingPercentEncoding]];
        NSMutableDictionary *postData = [NSMutableDictionary dictionaryWithDictionary:keyValues];
        [postData removeObjectForKey:@"url"];
        [postData removeObjectForKey:@"cache"];
        CameraViewController *cv = [[CameraViewController alloc] init];
        [cv setPostURL:path withCache:cache withPostData:postData succeed:^(NSURL *path) {
            [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true, '%@')", hashForJsCallback, [path absoluteString]]];
        } failed:^(NSError *error, NSURL *path) {
            [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', false, '%@', '%@')",
                                        hashForJsCallback, [path absoluteString], [error localizedDescription]]];
        }];
        [cv selectType:self];

    }else if ([scheme isEqualToString:@"imageupload"]) {
        NSString *hashForJsCallback = [url lastPathComponent];
        NSDictionary *keyValues = [self parseQuery:[url query]];
        NSURL *path = [NSURL URLWithString:[[keyValues valueForKey:@"url"] stringByRemovingPercentEncoding]];
        NSMutableDictionary *postData = [NSMutableDictionary dictionaryWithDictionary:keyValues];
        [postData removeObjectForKey:@"url"];
        CameraViewController *cv = [[CameraViewController alloc] init];
        [cv setPostURL:path withPostData:postData succeed:^(NSURL *path) {
            [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', true, ')", hashForJsCallback]];
        } failed:^(NSError *error, NSURL *path) {
            [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.execCollback('%@', false, '%@')",
                                        hashForJsCallback, [error localizedDescription]]];
        }];
        [cv selectType:self];
    }else if ([scheme isEqualToString:@"notification"]) {
        NSDictionary *keyValues = [self parseQuery:[url query]];
        NSString *body = [[keyValues valueForKey:@"body"] stringByRemovingPercentEncoding];
        NSString *category = [[keyValues valueForKey:@"category"] stringByRemovingPercentEncoding];
        NSString *date = [[keyValues valueForKey:@"date"] stringByRemovingPercentEncoding];

        UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
        UIUserNotificationSettings *mySettings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:mySettings];
        UILocalNotification *localNotification = [UILocalNotification new];
        localNotification.alertBody = body;
        localNotification.category = category;
        localNotification.soundName = UILocalNotificationDefaultSoundName;
        
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"ja_JP"]];
        [df setDateFormat:@"yyyyMMddHHmmss"];
        NSDate *fireDate = [df dateFromString:date];

        localNotification.fireDate = fireDate;
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
        
    }else if ([scheme isEqualToString:@"gatrack"]) {
        NSDictionary *keyValues = [self parseQuery:[url query]];
        NSString *title = [[keyValues valueForKey:@"title"] stringByRemovingPercentEncoding];
        id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
        [tracker set:kGAIScreenName value:title];
        [tracker send:[[GAIDictionaryBuilder createScreenView] build]];
        [tracker set:kGAIScreenName value:nil];
    }else if ([scheme isEqualToString:@"gaevent"]) {
        NSDictionary *keyValues = [self parseQuery:[url query]];
        NSString *category = [[keyValues valueForKey:@"category"] stringByRemovingPercentEncoding];
        NSString *action = [[keyValues valueForKey:@"action"] stringByRemovingPercentEncoding];
        NSString *label = [[keyValues valueForKey:@"label"] stringByRemovingPercentEncoding];
        NSString *screen = [[keyValues valueForKey:@"screen"] stringByRemovingPercentEncoding];
        id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
        [tracker set:kGAIScreenName value:screen];
        [tracker send:[[GAIDictionaryBuilder createEventWithCategory:category action:action label:label value:nil] build]];
        [tracker set:kGAIScreenName value:nil];
    }else if ([scheme isEqualToString:@"ttp"] || [scheme isEqualToString:@"ttps"]) {
        NSString *urlStr = [NSString stringWithFormat:@"h%@", [url absoluteString]];
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlStr]]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr]];
        }
//    }else if ([scheme isEqualToString:@"playmovie"]) {
        // TODO:
        // TODO:
        // TODO:
        // TODO:
        // TODO:
        // TODO:
        // TODO:
        // TODO:
        // TODO:
        // TODO:
        // TODO:
    } else {
        if([App isExportDomains:url]) {
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url];
            }
        }
    }
    
    return YES;
}

-(void)webView:(UIWebView*)webView runJavaScriptAlertPanelWithMessage:(NSString *)message
{
    NSLog(@"runJavaScriptAlertPanelWithMessage");
}

-(void)webView:(UIWebView*)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message
{
    NSLog(@"runJavaScriptConfirmPanelWithMessage");
}

-(void)webView:(UIWebView*)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText
{
    NSLog(@"runJavaScriptTextInputPanelWithPrompt");
}

-(void)webViewDidFinishLoad:(UIWebView *)webView
{
    [webView_ stringByEvaluatingJavaScriptFromString:@"document.documentElement.style.webkitUserSelect='none';"];
    [webView_ stringByEvaluatingJavaScriptFromString:@"document.documentElement.style.webkitTouchCallout='none';"];
}

#pragma mark NotificationBroadcastDelegate

- (void) notificatoinRemote:(NSDictionary*)userInfo
{
    NSError*error=nil;
    NSData*data=[NSJSONSerialization dataWithJSONObject:userInfo options:2 error:&error];
    NSString*jsonstr=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.remoteNotification('%@')", jsonstr]];
}

- (void) notificatoinLocal:(NSDictionary*)userInfo
{
    NSError*error=nil;
    NSData*data=[NSJSONSerialization dataWithJSONObject:userInfo options:2 error:&error];
    NSString*jsonstr=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    [self evaluatingJavaScript:[NSString stringWithFormat:@"nativeBridge__.localNotification('%@')", jsonstr]];
}

@end
