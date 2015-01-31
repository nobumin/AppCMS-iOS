//
//  ViewController.h
//  AppCMS
//
//  Created by 長島 伸光 on 2014/12/31.
//  Copyright (c) 2014年 MEAS. All rights reserved.
//

#define SERVER_PORT 10080

#import <UIKit/UIKit.h>
#import "CMSAppDelegate.h"
#import <GAI.h>
#import <GAIFields.h>
#import <GAIDictionaryBuilder.h>
//#import <WebKit/WebKit.h>

@interface CMSViewController : UIViewController <UIWebViewDelegate, NotificationBroadcastDelegate>{
    IBOutlet UIWebView *webView_;
}

// WKWebViewはもう少し様子見
//http://dev.classmethod.jp/references/ios8-webkit-wkwebview-1/
//@property (strong, nonatomic) WKWebView *wwebView_;

- (void)startHttpServer:(int)retry;

@end

