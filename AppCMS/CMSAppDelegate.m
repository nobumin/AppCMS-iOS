//
//  AppDelegate.m
//  AppCMS
//
//  Created by 長島 伸光 on 2014/12/31.
//  Copyright (c) 2014年 MEAS. All rights reserved.
//

#import "CMSAppDelegate.h"
#import "DownloadManager.h"
#import "CMSViewController.h"
#import <GAI.h>

@interface CMSAppDelegate () {
    id<NotificationBroadcastDelegate> notificattion_;
}

@end

@implementation CMSAppDelegate

- (void)alertUpdateUI
{
    Class class = NSClassFromString(@"UIAlertController");
    if(class){
        UIAlertController *alert = nil;
        alert = [UIAlertController alertControllerWithTitle:@""
                                                    message:@"コンテンツを更新します。"
                                             preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction *action) {
                                                      [self changeUI];
                                                  }]];
        [[self.window rootViewController] presentViewController:alert animated:YES completion:^{
        }];
    }else{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                        message:@"コンテンツを更新します。"
                                                       delegate:self
                                              cancelButtonTitle:nil
                                              otherButtonTitles:@"OK", nil];
        [alert show];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [self changeUI];
}

- (void)changeUI
{
    [self progressView];
    CMSViewController *vc = (CMSViewController*)[self.window rootViewController];
    if ([vc respondsToSelector:@selector(startHttpServer:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [vc startHttpServer:0];
            [self hiddenProgress];
        });
    }else{
        [self hiddenProgress];
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    //初期設定
    self.progressView = [[UIView alloc] initWithFrame:self.window.frame];
    self.progressView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    self.progressView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.8];
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [indicator startAnimating];
    [self.progressView addSubview:indicator];
    indicator.center = self.window.center;
    application.applicationIconBadgeNumber = -1;

    //リモート通知セットアップ
    if([self isUnderIOS8]) {
        [application registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeSound];
    }else{
        UIUserNotificationType types = UIUserNotificationTypeBadge|UIUserNotificationTypeSound|UIUserNotificationTypeAlert;
        UIUserNotificationSettings *mySettings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
        [application registerUserNotificationSettings:mySettings];
    }
    //
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    //DocumenntRoot確認
    if(![self hasDocumentRoot]) {
        NSError *error;
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm copyItemAtPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"htdocs"]
                    toPath:[self documentRoot] error:&error];
    }
    self.updateUI = NO;
    DownloadManager *dm = [DownloadManager buildManager];
    [dm offProgressDownloadUIPackage:^(BOOL sccess) {
        if(sccess) {
            [self alertUpdateUI];
        }
    }];

    //felloセットアップ
    [KonectNotificationsAPI initialize:self launchOptions:launchOptions appId:[self getConfigSetting:@"felloAppId"]];
    //google analyticsセットアップ
    [[GAI sharedInstance] trackerWithTrackingId:[self getConfigSetting:@"googleAnalytics"]];
    [GAI sharedInstance].trackUncaughtExceptions = YES;
    
    NSDictionary* userInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    if (userInfo != nil && notificattion_ != nil) {
        [notificattion_ notificatoinLocal:userInfo];
    }
    
    return YES;
}

-(void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    [application registerForRemoteNotifications];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    if(self.updateUI) {
        CMSViewController *vc = (CMSViewController*)[self.window rootViewController];
        if ([vc respondsToSelector:@selector(startHttpServer:)]) {
            self.updateUI = NO;
            [vc startHttpServer:0];
        }
    }
    application.applicationIconBadgeNumber = -1;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    //バックグラウンド処理
    DownloadManager *dm = [DownloadManager buildManager];
    [dm offProgressDownloadUIPackage:^(BOOL sccess) {
        self.updateUI = sccess;
        [self backgroudProcess:completionHandler];
    }];
}

- (void)backgroudProcess:(void (^)(UIBackgroundFetchResult))completionHandler
{
    DownloadManager *dm = [DownloadManager buildManager];
    [dm downloadBackground:^(BOOL sccess) {
        completionHandler(UIBackgroundFetchResultNewData);
    }];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    //リモート通知登録1
    [KonectNotificationsAPI setupNotifications:deviceToken];
    //リモート通知登録2
    //AppCMS
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
    fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [KonectNotificationsAPI processNotifications:userInfo];
    //通知内容
    dispatch_async(dispatch_get_main_queue(), ^{
        [notificattion_ notificatoinRemote:userInfo];
        completionHandler(UIBackgroundFetchResultNoData);
    });
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
//    NSLog(@">>> %@ <<<", userInfo);
}

//- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void(^)())completionHandler
//{
//}


- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    //http://starzero.hatenablog.com/entry/2014/06/18/234327
//    [self addCompletionHandler:completionHandler forSession:identifier];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    if (application.applicationState == UIApplicationStateActive) {
        if (notification.userInfo != nil && notificattion_ != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [notificattion_ notificatoinLocal:notification.userInfo];
            });
        }
        return;
    }
    
    if (application.applicationState == UIApplicationStateInactive) {
        if (notification.userInfo != nil && notificattion_ != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [notificattion_ notificatoinLocal:notification.userInfo];
            });
        }
        return;
    }
}

// このメソッドで、プッシュ通知からの起動後の処理を行うことが出来る
- (void)onLaunchFromNotification:(NSString *)notificationsId message:(NSString *)message extra:(NSDictionary *)extra
{
    NSLog(@"ここでextraの中身にひもづいたインセンティブの付与などを行うことが出来ます");
    //通知内容
}

- (BOOL)isUnderIOS8
{
    NSArray  *aOsVersions = [[[UIDevice currentDevice]systemVersion] componentsSeparatedByString:@"."];
    NSInteger iOsVersionMajor  = [[aOsVersions objectAtIndex:0] intValue];
    if (iOsVersionMajor < 8) {
        return YES;
    }
    
    return NO;
}

- (BOOL)isiPhone
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone){
        return YES;
    }
    return NO;
}

- (NSUUID*)uuid
{
    return [[UIDevice currentDevice] identifierForVendor];
}

- (NSString*)documentRoot
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsRoot = [NSString stringWithFormat:@"%@/htdocs/", [paths objectAtIndex:0]];
    return documentsRoot;
}

- (NSString*)cacheRoot
{
    NSString *cacheRoot = [NSString stringWithFormat:@"%@/%@/", [self documentRoot], [self getConfigSetting:@"cachePath"]];
    return cacheRoot;
}

- (BOOL)hasDocumentRoot
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL exist = [fm fileExistsAtPath:[self documentRoot] isDirectory:&isDir];
    if(exist) {
        return YES;
    }
    
    return NO;
}

- (void)setSetting:(NSString*)key value:(NSObject*)value
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:value forKey:key];
    [userDefaults synchronize];
}

- (NSObject*)getSetting:(NSString*)key
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults objectForKey:key];
}

- (void)removeSetting:(NSString*)key
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults removeObjectForKey:key];
    [userDefaults synchronize];
}

- (NSString*) getConfigSetting:(NSString*)key
{
    NSString *configPath = [NSString stringWithFormat:@"%@/appcms_config.plist", [[NSBundle mainBundle] bundlePath]];
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:configPath];
    return [config valueForKey:key];
}

- (BOOL)isExportDomains:(NSURL*)url
{
    NSArray *domains = [[self getConfigSetting:@"exportDomains"] componentsSeparatedByString:@","];
    if(domains) {
        for(NSString *domain in domains) {
            NSString *host = [url host];
            if([host hasSuffix:domain]) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (void)displayProgress
{
    [self.window.rootViewController.view addSubview:self.progressView];
}

- (void)hiddenProgress
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressView removeFromSuperview];
    });
}

- (void)setNotificationDelegate:(id<NotificationBroadcastDelegate>)notification
{
    notificattion_ = notification;
}

@end
