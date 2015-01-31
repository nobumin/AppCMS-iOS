//
//  CameraViewController.m
//  AppCMS
//
//  Created by 長島 伸光 on 2015/01/18.
//  Copyright (c) 2015年 MEAS. All rights reserved.
//

#import "CameraViewController.h"
#import "CMSAppDelegate.h"

@interface CameraViewController () {
    NSURL *postURL_;
    NSURL *cacheURL_;
    NSDictionary *postData_;
    UIViewController *viewController_;
    downloadSucceeded succeed_;
    downloadFailed failed_;
}

@end

@implementation CameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.delegate = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setPostURL:(NSURL *)url withPostData:(NSDictionary*)postData succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed
{
    postURL_ = url;
    cacheURL_ = nil;
    postData_ = postData;
    succeed_ = succeed;
    failed_ = failed;
}

- (void)setPostURL:(NSURL *)url withCache:(NSURL*)cacheURL withPostData:(NSDictionary*)postData succeed:(downloadSucceeded)succeed failed:(downloadFailed)failed
{
    postURL_ = url;
    cacheURL_ = cacheURL;
    postData_ = postData;
    succeed_ = succeed;
    failed_ = failed;
}

- (void)selectType:(UIViewController*)viewController
{
    if([App isUnderIOS8]) {
        UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@"Photo"
                                                        delegate:self cancelButtonTitle:@"Camera" destructiveButtonTitle:nil
                                               otherButtonTitles:@"Library", @"CameraRole", nil];
        as.cancelButtonIndex = 0;
        [as showInView:viewController.view];
        viewController_ = viewController;
    }else{
        UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"Photo" message:@""
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
        [actionSheet addAction:[UIAlertAction actionWithTitle:@"Camera"
                                                        style:UIAlertActionStyleDestructive
                                                      handler:^(UIAlertAction *action){
                                                          [self showCameraPicker:viewController];
                                                      }]];
        [actionSheet addAction:[UIAlertAction actionWithTitle:@"Library"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action){
                                                          [self showImagePicker:viewController];
                                                      }]];
        [actionSheet addAction:[UIAlertAction actionWithTitle:@"CameraRole"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action){
                                                          [self showCameraRolePicker:viewController];
                                                      }]];
        actionSheet.modalPresentationStyle = UIModalPresentationPopover;
        actionSheet.popoverPresentationController.sourceView = viewController.view;
        actionSheet.popoverPresentationController.sourceRect = CGRectMake(100.0, 20.0, 120.0, 120.0);
        [viewController presentViewController:actionSheet animated:YES completion:nil];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
- (void)showCameraPicker:(UIViewController*)viewController
{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        return;
    }
    self.sourceType = UIImagePickerControllerSourceTypeCamera;
    self.allowsEditing = YES;
    [viewController presentViewController:self animated:YES completion:nil];
}

- (void)showImagePicker:(UIViewController*)viewController
{
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.delegate = self;
    imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePickerController.allowsEditing = YES;
    [self presentViewController:imagePickerController animated:YES completion:nil];
}

- (void)showCameraRolePicker:(UIViewController*)viewController
{
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.delegate = self;
    imagePickerController.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    imagePickerController.allowsEditing = YES;
    [self presentViewController:imagePickerController animated:YES completion:nil];
}

// 画像が選択された時に呼ばれるデリゲートメソッド
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo
{
    [self dismissViewControllerAnimated:YES completion:nil];
    if(picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
        UIImageWriteToSavedPhotosAlbum(image, self, @selector(targetImage:didFinishSavingWithError:contextInfo:), NULL);
    }
    DownloadManager *dm = [DownloadManager buildManager];
    NSMutableDictionary *postData = [[NSMutableDictionary alloc] initWithCapacity:0];
    [postData setValue:image forKey:@"image"];
    [postData_ setValuesForKeysWithDictionary:postData_];
    if(cacheURL_) {
        [dm downloadWithCache:postURL_ datas:postData_ cache:cacheURL_ succeed:succeed_ failed:failed_];
    }else{
        [dm download:postURL_ datas:postData_ succeed:succeed_ failed:failed_];
    }
}

// 画像の選択がキャンセルされた時に呼ばれるデリゲートメソッド
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

// 画像の保存完了時に呼ばれるメソッド
- (void)targetImage:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)context
{
    //エラー処理
}

#pragma mark - UIActionSheetDelegate

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == actionSheet.cancelButtonIndex) {
        [self showCameraPicker:viewController_];
    }else if(buttonIndex == actionSheet.cancelButtonIndex+1) {
        [self showImagePicker:viewController_];
    }else{
        [self showCameraRolePicker:viewController_];
    }
}

@end
