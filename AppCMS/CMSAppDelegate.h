//
//  AppDelegate.h
//  AppCMS
//
//  Created by 長島 伸光 on 2014/12/31.
//  Copyright (c) 2014年 MEAS. All rights reserved.
//

#define App (CMSAppDelegate *)[[UIApplication sharedApplication] delegate]

#import <UIKit/UIKit.h>
#import <FelloPush/KonectNotificationsAPI.h>

@protocol NotificationBroadcastDelegate
@optional
- (void) notificatoinRemote:(NSDictionary*)userInfo;
- (void) notificatoinLocal:(NSDictionary*)userInfo;
@end

@class CMSViewController;

@interface CMSAppDelegate : UIResponder <UIApplicationDelegate, UIAlertViewDelegate, IKonectNotificationsCallback> {
    
}

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIView *progressView;
@property (readwrite) BOOL updateUI;

- (BOOL)isUnderIOS8;
- (BOOL)isiPhone;
- (NSUUID*)uuid;
- (NSString*)documentRoot;
- (NSString*)cacheRoot;
- (void)setSetting:(NSString*)key value:(NSObject*)value;
- (NSObject*)getSetting:(NSString*)key;
- (void)removeSetting:(NSString*)key;
- (NSString*) getConfigSetting:(NSString*)key;
- (void)displayProgress;
- (void)hiddenProgress;
- (BOOL)isExportDomains:(NSURL*)url;
- (void)setNotificationDelegate:(id<NotificationBroadcastDelegate>)notification;

@end

