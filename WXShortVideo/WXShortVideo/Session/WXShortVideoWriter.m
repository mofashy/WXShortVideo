//
//  WXShortVideoWriter.m
//  WXShortVideo
//
//  Created by 沈永聪 on 2019/4/28.
//  Copyright © 2019 WX. All rights reserved.
//

#import "WXShortVideoWriter.h"
#import <AVFoundation/AVFoundation.h>

@interface WXShortVideoWriter ()
@property (nonatomic) dispatch_queue_t assetWriterQueue;

@property (strong, nonatomic) AVAssetWriter *assetWriter;
@property (strong, nonatomic) AVAssetWriterInput *videoWriterInput;
@property (strong, nonatomic) AVAssetWriterInput *audioWriterInput;

@property (copy, nonatomic) NSString *fileUrl;
@property (assign, nonatomic) BOOL recording;

@property (copy, nonatomic) void (^handler) (NSString *);
@end

@implementation WXShortVideoWriter

- (void)dealloc {
    _assetWriter = nil;
    _videoWriterInput = nil;
    _audioWriterInput = nil;
    
    NSLog(@"%@ dealloc", NSStringFromClass([self class]));
}

- (instancetype)initWithCompleteWritingHandler:(void (^)(NSString * _Nonnull))handler {
    self = [super init];
    if (self) {
        _handler = handler;
        [self setup];
    }
    return self;
}

- (void)setup {
    NSDictionary *videoSetting = @{AVVideoCodecKey: AVVideoCodecH264,
                                   AVVideoWidthKey: @(720),
                                   AVVideoHeightKey: @(1280),
                                   AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
                                   AVVideoCompressionPropertiesKey: @{
                                           AVVideoExpectedSourceFrameRateKey: @(15),
                                           AVVideoMaxKeyFrameIntervalKey: @(15),
                                           AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                           AVVideoAverageBitRateKey: @(1280 * 720 * 2),
                                           }};
    NSDictionary *audioSetting = @{AVFormatIDKey: [NSNumber numberWithInt:kAudioFormatMPEG4AAC],
                                   AVNumberOfChannelsKey: @(2),
                                   AVSampleRateKey: @(22050),
                                   };
    
    NSError *error = nil;
    _fileUrl = [NSTemporaryDirectory() stringByAppendingString:[NSString stringWithFormat:@"%@.mp4", [[NSDate date] description]]];
    _assetWriter = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:_fileUrl] fileType:AVFileTypeMPEG4 error:&error];
    _assetWriter.shouldOptimizeForNetworkUse = YES;
    
    if (error) {
        NSLog(@"AVAssetWriter init error: %@", [error description]);
        return;
    }
    
    _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSetting];
    _videoWriterInput.expectsMediaDataInRealTime = YES;
    
    if ([_assetWriter canAddInput:_videoWriterInput]) {
        [_assetWriter addInput:_videoWriterInput];
    }
    
    _audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSetting];
    _audioWriterInput.expectsMediaDataInRealTime = YES;
    
    if ([_assetWriter canAddInput:_audioWriterInput]) {
        [_assetWriter addInput:_audioWriterInput];
    }
    
    _assetWriterQueue = dispatch_queue_create("com.wx.queue.asset.write", DISPATCH_QUEUE_SERIAL);
}

- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer type:(WXSampleBufferType)type {
    if (self.assetWriter.status > AVAssetWriterStatusWriting) {
        return;
    }
    
    CFRetain(sampleBuffer);
    dispatch_async(self.assetWriterQueue, ^{
        if (self.assetWriter.status == AVAssetWriterStatusUnknown) {
            self.recording = [self.assetWriter startWriting];
            [self.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
        }
        
        if (type == WXSampleBufferTypeVideo && [self.videoWriterInput isReadyForMoreMediaData]) {
            [self.videoWriterInput appendSampleBuffer:sampleBuffer];
        }
        if (type == WXSampleBufferTypeAudio && [self.audioWriterInput isReadyForMoreMediaData]) {
            [self.audioWriterInput appendSampleBuffer:sampleBuffer];
        }
        CFRelease(sampleBuffer);
    });
}

- (void)endWriting {
    if (self.assetWriter.status == AVAssetWriterStatusWriting) {
        [self.videoWriterInput markAsFinished];
        [self.audioWriterInput markAsFinished];
        
        [self.assetWriter finishWritingWithCompletionHandler:^{
            NSLog(@"End writing.");
            NSLog(@"Video attributes: %@", [[NSFileManager defaultManager] attributesOfItemAtPath:_fileUrl error:nil]);
            _handler ? _handler(_fileUrl) : nil;
        }];
    }
}

@end
