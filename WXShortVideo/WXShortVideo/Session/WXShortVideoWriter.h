//
//  WXShortVideoWriter.h
//  WXShortVideo
//
//  Created by 沈永聪 on 2019/4/28.
//  Copyright © 2019 WX. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, WXSampleBufferType) {
    WXSampleBufferTypeVideo,
    WXSampleBufferTypeAudio
};

@interface WXShortVideoWriter : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCompleteWritingHandler:(void (^)(NSString *))handler;
- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer type:(WXSampleBufferType)type;
- (void)endWriting;
@end

NS_ASSUME_NONNULL_END
