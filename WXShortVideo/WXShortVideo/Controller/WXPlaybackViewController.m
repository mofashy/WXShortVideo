//
//  WXPlaybackViewController.m
//  WXShortVideo
//
//  Created by macOS on 2017/11/15.
//  Copyright © 2017年 WX. All rights reserved.
//

#import "WXPlaybackViewController.h"

typedef NS_ENUM(NSUInteger, WXPlayerStatus) {
    WXPlayerStatusIdle,
    WXPlayerStatusPlaying,
    WXPlayerStatusPause,
    WXPlayerStatusEnd,
};

@interface WXPlaybackViewController ()
@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVPlayerLayer *playerLayer;

@property (strong, nonatomic) UIView *baseToolboxView;
@property (strong, nonatomic) UIView *playToolboxView;
@property (strong, nonatomic) UIButton *smallPlayButton;
@property (strong, nonatomic) UISlider *slider;
@property (strong, nonatomic) UILabel *timeLabel;
@property (strong, nonatomic) UILabel *durationLabel;

@property (strong, nonatomic) id timeObserver;
@property (copy, nonatomic) NSString *videoPath;
@property (strong, nonatomic) UIImage *previewImage;

@property (assign, nonatomic) WXPlayerStatus playerStatus;
@end

@implementation WXPlaybackViewController

#pragma mark - Appearance

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

#pragma mark - Life cycle

- (void)dealloc {
    [_player pause];
    [_player.currentItem cancelPendingSeeks];
    [_player.currentItem.asset cancelLoading];
    [_player replaceCurrentItemWithPlayerItem:nil];
    _player = nil;
    _playerStatus = WXPlayerStatusIdle;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    NSLog(@"%@ dealloc", NSStringFromClass([self class]));
}

- (instancetype)initWithVideoPath:(NSString *)videoPath previewImage:(UIImage *)previewImage {
    NSParameterAssert(videoPath != nil);
    self = [super init];
    if (self) {
        _videoPath = videoPath;
        _previewImage = previewImage;
        
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:videoPath]];
        
        __weak __typeof(self)weakSelf = self;
        [asset loadValuesAsynchronouslyForKeys:@[@"playable"] completionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf prepareToPlayAsset:asset];
            });
        }];
    }
    
    return self;
}

- (instancetype)initWithAsset:(AVAsset *)asset previewImage:(UIImage *)previewImage {
    NSParameterAssert(asset != nil);
    self = [super init];
    if (self) {
        _previewImage = previewImage;
        
        __weak __typeof(self)weakSelf = self;
        [asset loadValuesAsynchronouslyForKeys:@[@"playable"] completionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf prepareToPlayAsset:asset];
            });
        }];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor blackColor];
    
    [self setupPlayer];
    [self setupBaseToolboxView];
    [self setupPlayToolboxView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Setup

- (void)setupPlayer {
    BOOL isIphoneX = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && [UIScreen mainScreen].bounds.size.height == 812.0f;
    
    _player = [[AVPlayer alloc] init];
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    _playerLayer.frame = isIphoneX ? CGRectMake(0, 44, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame) - 88) : self.view.bounds;
    [self.view.layer addSublayer:_playerLayer];
    
    __weak __typeof(self)weakSelf = self;
    _timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        float current = CMTimeGetSeconds(time);
        float duration = CMTimeGetSeconds(weakSelf.player.currentItem.duration);
        if (current && duration) {
            weakSelf.durationLabel.text = [weakSelf timeStringFromseconds:(int)round(duration)];
            weakSelf.timeLabel.text = [weakSelf timeStringFromseconds:(int)round(current)];
            [weakSelf.slider setValue:(current / duration) animated:YES];
        }
    }];
}

- (void)setupBaseToolboxView {
    _baseToolboxView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), 64)];
    _baseToolboxView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_baseToolboxView];
    
    // 返回
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    backButton.frame = CGRectMake(10, 10, 35, 35);
    [backButton setBackgroundImage:[UIImage imageNamed:@"btn_camera_cancel_a"] forState:UIControlStateNormal];
    [backButton setBackgroundImage:[UIImage imageNamed:@"btn_camera_cancel_b"] forState:UIControlStateHighlighted];
    [backButton addTarget:self action:@selector(backButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.baseToolboxView addSubview:backButton];
}

- (void)setupPlayToolboxView {
    _playToolboxView = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.frame) - 70, CGRectGetWidth(self.view.frame), 70)];
    _playToolboxView.backgroundColor = [UIColor clearColor];
#if !DEBUG
    _playToolboxView.hidden = self.loopEnabled;
#endif
    [self.view addSubview:_playToolboxView];
    
    _smallPlayButton = [[UIButton alloc] initWithFrame:CGRectMake(20, 0, 30, 30)];
    [_smallPlayButton setImage:[UIImage imageNamed:@"play_small"] forState:UIControlStateNormal];
    [_smallPlayButton setImage:[UIImage imageNamed:@"pause_small"] forState:UIControlStateSelected];
    [_smallPlayButton addTarget:self action:@selector(smallPlayButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [_playToolboxView addSubview:_smallPlayButton];
    
    _timeLabel = [[UILabel alloc] init];
    _timeLabel.font = [UIFont systemFontOfSize:10];
    _timeLabel.text = @"00:00";
    _timeLabel.textColor = [UIColor whiteColor];
    [_playToolboxView addSubview:_timeLabel];
    CGSize size = [_timeLabel sizeThatFits:CGSizeZero];
    _timeLabel.frame = CGRectMake(20 + 30 + 10, (30 - size.height) / 2.0f, size.width + 5, size.height);
    
    _durationLabel = [[UILabel alloc] init];
    _durationLabel.font = [UIFont systemFontOfSize:10];
    _durationLabel.text = @"00:00";
    _durationLabel.textColor = [UIColor whiteColor];
    [_playToolboxView addSubview:_durationLabel];
    _durationLabel.frame = CGRectMake(CGRectGetWidth(self.view.frame) - size.width - 5 - 20, (30 - size.height) / 2.0f, size.width + 5, size.height);
    
    _slider = [[UISlider alloc] initWithFrame:CGRectMake(CGRectGetMaxX(_timeLabel.frame) + 5, 5, CGRectGetMinX(_durationLabel.frame) - CGRectGetMaxX(_timeLabel.frame) - 10, 20)];
    _slider.minimumValue = 0.0;
    _slider.maximumValue = 1.0;
    _slider.tintColor = [UIColor whiteColor];
    [_slider setThumbImage:[UIImage imageNamed:@"slider_thumb"] forState:UIControlStateNormal];
    [_slider addTarget:self action:@selector(sliderEvent:) forControlEvents:UIControlEventValueChanged];
    [_playToolboxView addSubview:_slider];
}

#pragma mark - Action

- (void)backButtonEvent:(id)sender {
    if (self.playerStatus == WXPlayerStatusPlaying) {
        [self.player pause];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)smallPlayButtonEvent:(id)sender {
    UIButton *button = (UIButton *)sender;
    button.selected = !button.isSelected;
    
    if (button.isSelected) {
        if (self.playerStatus == WXPlayerStatusEnd) {
            [self.player seekToTime:kCMTimeZero];
        }
        [self.player play];
        self.playerStatus = WXPlayerStatusPlaying;
    } else {
        [self.player pause];
        self.playerStatus = WXPlayerStatusPause;
    }
}

- (void)sliderEvent:(id)sender {
    UISlider *slider = (UISlider *)sender;
    self.timeLabel.text = [self timeStringFromseconds:(int)slider.value];
    [self.player pause];
    [self.player seekToTime:CMTimeMake(slider.value * CMTimeGetSeconds(self.player.currentItem.duration), 1.0)];
    [self.player play];
}

#pragma mark - KVO

- (void)playerItemDidReachEnd:(NSNotification *)noti {
    self.playerStatus = WXPlayerStatusEnd;
    self.smallPlayButton.selected = NO;
    if (self.loopEnabled) {
        [self.player seekToTime:kCMTimeZero];
        [self.player play];
        self.playerStatus = WXPlayerStatusPlaying;
        self.smallPlayButton.selected = YES;
    }
}

#pragma mark - Helper

- (void)prepareToPlayAsset:(AVAsset *)asset {
    NSError *error = nil;
    AVKeyValueStatus keyStatus = [asset statusOfValueForKey:@"playable" error:&error];
    if (keyStatus == AVKeyValueStatusFailed) {
        [self alertMessage:[error localizedDescription]];
        return;
    }
    
    if (!asset.playable) {
        [self alertMessage:@"该视频资源无效"];
        return;
    }
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];
    
    self.durationLabel.text = [self timeStringFromseconds:round(CMTimeGetSeconds(asset.duration))];
    [self.player replaceCurrentItemWithPlayerItem:playerItem];
    [self.player play];
    self.smallPlayButton.selected = YES;
    self.playerStatus = WXPlayerStatusPlaying;
}

- (void)alertMessage:(NSString *)msg {
    [[[UIAlertView alloc] initWithTitle:@"提示" message:msg delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil] show];
}

- (NSString *)timeStringFromseconds:(int)seconds {
    return [NSString stringWithFormat:@"%02d:%02d", seconds / 60, seconds % 60];
}

@end
