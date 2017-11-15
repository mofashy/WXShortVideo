//
//  WXPlaybackViewController.h
//  WXShortVideo
//
//  Created by macOS on 2017/11/15.
//  Copyright © 2017年 WX. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface WXPlaybackViewController : UIViewController
@property (assign, nonatomic) BOOL loopEnabled;

- (instancetype)initWithVideoPath:(NSString *)videoPath previewImage:(UIImage *)previewImage;
- (instancetype)initWithAsset:(AVAsset *)asset previewImage:(UIImage *)previewImage;
@end
