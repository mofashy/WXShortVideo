//
//  WXShortVideoSession.m
//  WXShortVideo
//
//  Created by macOS on 2017/11/14.
//  Copyright © 2017年 WX. All rights reserved.
//

#import "WXShortVideoSession.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <VideoToolbox/VideoToolbox.h>
#import <GLKit/GLKit.h>
#import <OpenGLES/EAGL.h>

@interface WXShortVideoSession () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureVideoDataOutput *videoDataOutput;
@property (strong, nonatomic) AVCaptureAudioDataOutput *audioDataOutput;
@property (strong, nonatomic) AVCaptureStillImageOutput *stilImageOutput;
@property (strong, nonatomic) AVCaptureConnection *videoConnection;
@property (strong, nonatomic) AVCaptureConnection *audioConnection;

@property (strong, nonatomic) AVAssetWriter *assetWriter;
@property (strong, nonatomic) AVAssetWriterInput *videoWriterInput;
@property (strong, nonatomic) AVAssetWriterInput *audioWriterInput;

@property (strong, nonatomic) EAGLContext *glContext;
@property (strong, nonatomic) CIContext *ciContext;
@property (strong, nonatomic) GLKView *glView;

@property (nonatomic) dispatch_queue_t videoWriterQueue;
@property (nonatomic) dispatch_queue_t audioWriterQueue;

@property (assign, nonatomic) CGRect bounds;
@property (assign, nonatomic) BOOL recording;

@property (copy, nonatomic) NSString *fileUrl;
@end

@implementation WXShortVideoSession

#pragma mark - Life cycle

- (void)dealloc {
    _captureSession = nil;
    _videoDataOutput = nil;
    _audioDataOutput = nil;
    _videoConnection = nil;
    _audioConnection = nil;
    _stilImageOutput = nil;
    _assetWriter = nil;
    _videoWriterInput = nil;
    _audioWriterInput = nil;
    _glContext = nil;
    _ciContext = nil;
    
    NSLog(@"%@ dealloc", NSStringFromClass([self class]));
}

- (instancetype)initWithPreviewView:(UIView *)view {
    self = [super init];
    if (self) {
        _bounds = view.bounds;
        [self setupCaptureSession];
        [self setupGLViewOnView:view];
        [self setupWriter];
    }
    return self;
}

#pragma mark - Setup

- (void)setupCaptureSession {
    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    
    AVCaptureDevice *defaultVideoDevice;
    NSArray *availableCameraDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in availableCameraDevices) {
        if (device.position == AVCaptureDevicePositionBack) {
            defaultVideoDevice = device;
            break;
        }
        
        defaultVideoDevice = device;
    }
    
    NSError *error = nil;
    AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:defaultVideoDevice error:&error];
    if (!error) {
        if ([_captureSession canAddInput:videoDeviceInput]) {
            [_captureSession addInput:videoDeviceInput];
        }
    }
    
    AVCaptureDevice *defaultAudioDevice = nil;
    NSArray *availableAudioDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    defaultAudioDevice = [availableAudioDevices firstObject];
    
    error = nil;
    AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:defaultAudioDevice error:&error];
    if (!error) {
        if ([_captureSession canAddInput:audioDeviceInput]) {
            [_captureSession addInput:audioDeviceInput];
        }
    }
    
    _videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoDataOutput setSampleBufferDelegate:self queue:dispatch_queue_create("video sample buffer delegate", DISPATCH_QUEUE_SERIAL)];
    if ([_captureSession canAddOutput:_videoDataOutput]) {
        [_captureSession addOutput:_videoDataOutput];
    }
    
    _audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    [_audioDataOutput setSampleBufferDelegate:self queue:dispatch_queue_create("audio sample buffer delegate", DISPATCH_QUEUE_SERIAL)];
    if ([_captureSession canAddOutput:_audioDataOutput]) {
        [_captureSession addOutput:_audioDataOutput];
    }
    
    _videoConnection = [_videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    _videoConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    _audioConnection = [_audioDataOutput connectionWithMediaType:AVMediaTypeAudio];
    
    _stilImageOutput = [[AVCaptureStillImageOutput alloc] init];
    if ([_captureSession canAddOutput:_stilImageOutput]) {
        [_captureSession addOutput:_stilImageOutput];
    }
}

- (void)setupGLViewOnView:(UIView *)view {
    _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    _glView = [[GLKView alloc] initWithFrame:view.bounds context:_glContext];
    _glView.enableSetNeedsDisplay = NO;
    [view addSubview:_glView];
    _ciContext = [CIContext contextWithEAGLContext:_glContext];
}

- (void)setupWriter {
    _videoWriterQueue = dispatch_queue_create("com.wx.queue.video_writing", DISPATCH_QUEUE_SERIAL);
    _audioWriterQueue = dispatch_queue_create("com.wx.queue.audio_writing", DISPATCH_QUEUE_SERIAL);
    
    NSDictionary *videoSetting = @{AVVideoCodecKey: AVVideoCodecH264,
                                   AVVideoWidthKey: @540,
                                   AVVideoHeightKey: @960,
                                   AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
                                   AVVideoCompressionPropertiesKey: @{
                                           AVVideoExpectedSourceFrameRateKey: @15,
                                           AVVideoMaxKeyFrameIntervalKey: @15,
                                           AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                           AVVideoAverageBitRateKey: @1024000,
                                           }};
    NSDictionary *audioSetting = @{AVFormatIDKey: [NSNumber numberWithInt:kAudioFormatMPEG4AAC],
                                   AVNumberOfChannelsKey: @1,
                                   AVSampleRateKey: @22050,
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
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate、AVCaptureAudioDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    @synchronized(self) {
        @autoreleasepool {
            // Preview
            if (output == self.videoDataOutput) {
                // Video
                CVImageBufferRef imageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer);
                CIImage *image = [CIImage imageWithCVPixelBuffer:imageBufferRef];
                if (_glContext != [EAGLContext currentContext]) {
                    [EAGLContext setCurrentContext:_glContext];
                }
                
                [_glView bindDrawable];
                CGFloat scale = [UIScreen mainScreen].scale;
                CGRect destRect = CGRectApplyAffineTransform(_bounds, CGAffineTransformMakeScale(scale, scale));
                [_ciContext drawImage:image inRect:destRect fromRect:[image extent]];
                [_glView display];
            } else {
                // Audio
            }
            
            // Write
            CFRetain(sampleBuffer);
            if (self.recording) {
                if (self.assetWriter.status > AVAssetWriterStatusWriting) {
                    CFRelease(sampleBuffer);
                    return;
                }
                
                if (self.assetWriter.status == AVAssetWriterStatusUnknown) {
                    self.recording = [self.assetWriter startWriting];
                    [self.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
                }
                
                if (output == self.videoDataOutput) {
                    dispatch_async(self.videoWriterQueue, ^{
                        if ([self.videoWriterInput isReadyForMoreMediaData]) {
                            [self.videoWriterInput appendSampleBuffer:sampleBuffer];
                        }
                        CFRelease(sampleBuffer);
                    });
                } else if (output == self.audioDataOutput) {
                    dispatch_async(self.audioWriterQueue, ^{
                        if ([self.audioWriterInput isReadyForMoreMediaData]) {
                            [self.audioWriterInput appendSampleBuffer:sampleBuffer];
                        }
                        CFRelease(sampleBuffer);
                    });
                }
            } else {
                CFRelease(sampleBuffer);
            }
        }
    }
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
}

#pragma mark - Public

- (void)startRunning {
    if (![self.captureSession isRunning]) {
        [self.captureSession startRunning];
    }
}

- (void)stopRunning {
    if ([self.captureSession isRunning]) {
        [self.captureSession stopRunning];
    }
}

- (void)startRecording {
    self.recording = YES;
    NSLog(@"Start writing.");
}

- (void)endRecording {
    self.recording = NO;
    
    if (self.assetWriter.status == AVAssetWriterStatusWriting) {
        [self.videoWriterInput markAsFinished];
        [self.audioWriterInput markAsFinished];
        
        [self.assetWriter finishWritingWithCompletionHandler:^{
            NSLog(@"End writing.");
            NSLog(@"Video attributes: %@", [[NSFileManager defaultManager] attributesOfItemAtPath:_fileUrl error:nil]);
            if ([self.delegate respondsToSelector:@selector(finishExportVideo:)]) {
                [self.delegate finishExportVideo:[self.fileUrl copy]];
            }
        }];
    }
}

@end
