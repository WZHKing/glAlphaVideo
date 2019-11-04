//
//  NextViewController.m
//  glAlphaVideo
//
//  Created by wzh on 2019/11/4.
//  Copyright © 2019 wzh. All rights reserved.
//

#import "NextViewController.h"
#import "AlphaVideoPlayerView.h"

@interface NextViewController ()
@property(nonatomic, strong) AlphaVideoPlayerView *playerView;

@end

@implementation NextViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIImageView *imgView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    imgView.image = [UIImage imageNamed:@"ScreenShot.png"];
    [self.view addSubview:imgView];
    _playerView = [[AlphaVideoPlayerView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:_playerView];
    [_playerView playWithURL:_videoURL];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [_playerView stop];
}

@end
