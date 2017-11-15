//
//  WXShortVideoSession.h
//  WXShortVideo
//
//  Created by macOS on 2017/11/14.
//  Copyright © 2017年 WX. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol WXShortVideoSessionDelegate;

@interface WXShortVideoSession : NSObject
@property (weak, nonatomic) id <WXShortVideoSessionDelegate> delegate;

- (instancetype)initWithPreviewView:(UIView *)view;

- (void)startRunning;
- (void)stopRunning;
- (void)startRecording;
- (void)endRecording;
@end


@protocol WXShortVideoSessionDelegate <NSObject>
- (void)finishExportVideo:(NSString *)fileUrl;
@end
