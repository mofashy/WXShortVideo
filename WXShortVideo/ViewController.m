//
//  ViewController.m
//  WXShortVideo
//
//  Created by macOS on 2017/11/14.
//  Copyright © 2017年 WX. All rights reserved.
//

#import "ViewController.h"
#import "WXCaptureViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)buttonEvent:(id)sender {
    [self presentViewController:[[WXCaptureViewController alloc] init] animated:YES completion:nil];
}

@end
