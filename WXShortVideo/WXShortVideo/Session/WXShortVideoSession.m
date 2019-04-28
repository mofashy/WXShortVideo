//
//  WXShortVideoSession.m
//  WXShortVideo
//
//  Created by macOS on 2017/11/14.
//  Copyright © 2017年 WX. All rights reserved.
//

#import "WXShortVideoSession.h"
#import "WXShortVideoWriter.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <VideoToolbox/VideoToolbox.h>

@interface WXShortVideoSession () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureVideoDataOutput *videoDataOutput;
@property (strong, nonatomic) AVCaptureAudioDataOutput *audioDataOutput;
@property (strong, nonatomic) AVCaptureConnection *videoConnection;
@property (strong, nonatomic) AVCaptureConnection *audioConnection;

@property (strong, nonatomic) WXShortVideoWriter *assetWriter;

@property (nonatomic) dispatch_queue_t videoDataOutputQueue;
@property (nonatomic) dispatch_queue_t audioDataOutputQueue;

@property (assign, nonatomic) CGRect bounds;
@property (assign, nonatomic) BOOL recording;

@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@end

@implementation WXShortVideoSession

#pragma mark - Life cycle

- (void)dealloc {
    _assetWriter = nil;
    _captureSession = nil;
    _videoDataOutput = nil;
    _audioDataOutput = nil;
    _videoConnection = nil;
    _audioConnection = nil;
    
    NSLog(@"%@ dealloc", NSStringFromClass([self class]));
}

- (instancetype)initWithPreviewView:(UIView *)view {
    self = [super init];
    if (self) {
        _bounds = view.bounds;
        [self setupCaptureSession];
        [self setupPreviewLayerOnView:view];
        [self setupWriter];
    }
    return self;
}

#pragma mark - Setup

- (void)setupCaptureSession {
    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    
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
    
    _videoDataOutputQueue = dispatch_queue_create("com.wx.queue.video.data", DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(_videoDataOutputQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    _videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoDataOutput setSampleBufferDelegate:self queue:_videoDataOutputQueue];
    if ([_captureSession canAddOutput:_videoDataOutput]) {
        [_captureSession addOutput:_videoDataOutput];
    }
    
    _audioDataOutputQueue = dispatch_queue_create("com.wx.queue.audio.data", DISPATCH_QUEUE_SERIAL);
    _audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    [_audioDataOutput setSampleBufferDelegate:self queue:_audioDataOutputQueue];
    if ([_captureSession canAddOutput:_audioDataOutput]) {
        [_captureSession addOutput:_audioDataOutput];
    }
    
    _videoConnection = [_videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    _videoConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    _audioConnection = [_audioDataOutput connectionWithMediaType:AVMediaTypeAudio];
}

- (void)setupPreviewLayerOnView:(UIView *)view {
    _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
    _previewLayer.frame = view.bounds;
    [view.layer insertSublayer:_previewLayer above:0];
}

- (void)setupWriter {
    _assetWriter = [[WXShortVideoWriter alloc] initWithCompleteWritingHandler:^(NSString * _Nonnull fileUrl) {
        if ([self.delegate respondsToSelector:@selector(finishExportVideo:)]) {
            [self.delegate finishExportVideo:[fileUrl copy]];
        }
    }];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate、AVCaptureAudioDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    @synchronized(self) {
        // Write
        if (self.recording) {
            [self.assetWriter appendSampleBuffer:sampleBuffer type:connection == _videoConnection ? WXSampleBufferTypeVideo : WXSampleBufferTypeAudio];
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
    
    [self.assetWriter endWriting];
}

@end
