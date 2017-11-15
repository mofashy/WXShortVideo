//
//  WXCaptureViewController.m
//  WXShortVideo
//
//  Created by macOS on 2017/11/14.
//  Copyright © 2017年 WX. All rights reserved.
//

#import "WXCaptureViewController.h"
#import "WXPlaybackViewController.h"
#import "WXShortVideoSession.h"

@interface WXCaptureViewController () <WXShortVideoSessionDelegate>
@property (strong, nonatomic) WXShortVideoSession *shortVideoSession;

@property (strong, nonatomic) UIButton *closeButton;
@property (strong, nonatomic) UIButton *recordButton;
@end

@implementation WXCaptureViewController

#pragma mark - Life cycle

- (void)dealloc {
    _shortVideoSession = nil;
    NSLog(@"%@ dealloc", NSStringFromClass([self class]));
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor blackColor];
    
    [self setupShortVideoSession];
    [self setupButtons];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.shortVideoSession startRunning];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.shortVideoSession stopRunning];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Setup

- (void)setupShortVideoSession {
    _shortVideoSession = [[WXShortVideoSession alloc] initWithPreviewView:self.view];
    _shortVideoSession.delegate = self;
}

- (void)setupButtons {
    _closeButton = [[UIButton alloc] init];
    _closeButton.frame = CGRectMake(10, 10, 35, 35);
    [_closeButton setTitle:@"Close" forState:UIControlStateNormal];
    [_closeButton addTarget:self action:@selector(closeButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_closeButton];
    
    CGFloat width = CGRectGetWidth(self.view.frame);
    CGFloat height = CGRectGetHeight(self.view.frame);
    _recordButton = [[UIButton alloc] init];
    _recordButton.layer.cornerRadius = 75.0 / 2;
    _recordButton.layer.masksToBounds = YES;
    _recordButton.frame = CGRectMake((width - 75.0) / 2, height - 75.0 - 64.0, 75.0, 75.0);
    _recordButton.backgroundColor = [UIColor whiteColor];
    [_recordButton addTarget:self action:@selector(recordButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_recordButton];
}

#pragma mark - WXShortVideoSessionDelegate

- (void)finishExportVideo:(NSString *)fileUrl {
    dispatch_async(dispatch_get_main_queue(), ^{
        WXPlaybackViewController *playbackVc = [[WXPlaybackViewController alloc] initWithVideoPath:fileUrl previewImage:nil];
        playbackVc.loopEnabled = YES;
        [self presentViewController:playbackVc animated:YES completion:nil];
    });
}

#pragma mark - Action

- (void)closeButtonEvent:(UIButton *)sender {
    [self.shortVideoSession stopRunning];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)recordButtonEvent:(UIButton *)sender {
    sender.selected = !sender.isSelected;
    if (sender.selected) {
        [self.shortVideoSession startRecording];
    } else {
        [self.shortVideoSession endRecording];
    }
}

@end
