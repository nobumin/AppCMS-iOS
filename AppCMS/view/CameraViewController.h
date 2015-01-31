//
//  CameraViewController.h
//  AppCMS
//
//  Created by 長島 伸光 on 2015/01/18.
//  Copyright (c) 2015年 MEAS. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DownloadManager.h"

@interface CameraViewController : UIImagePickerController <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate> {
    
}

- (void)setPostURL:(NSURL*)url withPostData:(NSDictionary*)postData succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed;
- (void)setPostURL:(NSURL *)url withCache:(NSURL*)cacheURL withPostData:(NSDictionary*)postData succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed;
- (void)selectType:(UIViewController*)viewController;

@end
