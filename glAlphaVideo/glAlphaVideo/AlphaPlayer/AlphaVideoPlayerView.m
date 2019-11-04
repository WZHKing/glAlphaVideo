//
//  AlphaVideoPlayerView.m
//  glAlphaVideo
//
//  Created by wzh on 2019/11/4.
//  Copyright © 2019 wzh. All rights reserved.
//

#import "AlphaVideoPlayerView.h"
#import <AVFoundation/AVFoundation.h>
#import "AlphaVideoRenderView.h"

# define ONE_FRAME_DURATION 0.03

@interface AlphaVideoPlayerView()<AVPlayerItemOutputPullDelegate>
{
    dispatch_queue_t _videoOutputQueue;
}
@property(nonatomic,strong) AVPlayer *player;
@property(nonatomic,strong) AVPlayerItemVideoOutput *videoOutPut;
@property(nonatomic,strong) CADisplayLink *displayLink;
@property(nonatomic, strong) AlphaVideoRenderView *renderView;
@property(nonatomic, assign) BOOL isResetFrame;
@end

@implementation AlphaVideoPlayerView

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder]) {
        [self commonInit];
    }
    return self;
}
- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self commonInit];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)commonInit
{
    self.contentMode = UIViewContentModeScaleAspectFit;
    self.userInteractionEnabled = NO;
    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];
    self.layer.masksToBounds = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didPlayToEnd) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    // 监听耳机插入和拔掉通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChangeListenerCallback:) name:AVAudioSessionRouteChangeNotification object:nil];
    
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [_displayLink setPaused:YES];
    
    //设置输出格式
    NSMutableDictionary *pixBuffAttributes = [NSMutableDictionary dictionary];
    [pixBuffAttributes setObject:@(kCVPixelFormatType_32BGRA) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    self.videoOutPut =  [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
    _videoOutputQueue = dispatch_queue_create("videoOutputQueue", DISPATCH_QUEUE_SERIAL);
    [self.videoOutPut setDelegate:self queue:_videoOutputQueue];
    
    _renderView = [[AlphaVideoRenderView alloc] initWithFrame:self.bounds];
    [self addSubview:_renderView];
}

- (void)playWithURL:(NSURL *)url
{
    if (url == nil) {
        [self didPlayToEnd];
        return;
    }
    AVURLAsset *asset = [AVURLAsset assetWithURL:url];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
    _player = [AVPlayer playerWithPlayerItem:playerItem];
    [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [_player play];
    [_videoOutPut requestNotificationOfMediaDataChangeWithAdvanceInterval:ONE_FRAME_DURATION];
    [_player.currentItem addOutput:_videoOutPut];
}

- (void)stop
{
    if (_player) {
        [_player pause];
        [_player.currentItem removeObserver:self forKeyPath:@"status"];
        _player = nil;
    }
    if (_displayLink) {
        [_displayLink invalidate];
        _displayLink = nil;
    }
}
- (void)pause:(BOOL)paused
{
    if (paused) {
        [_player pause];
    } else {
        [_player play];
    }
    if (_displayLink) {
        [self.displayLink setPaused:paused];
    }
}

#pragma mark - AVPlayerItemOutputPullDelegate

- (void)outputMediaDataWillChange:(AVPlayerItemOutput *)sender
{
    // Restart display link.
    [self.displayLink setPaused:NO];
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == self.player.currentItem) {
        if ([keyPath isEqualToString:@"status"]) {
            if (self.player.currentItem.status == AVPlayerItemStatusFailed) {
                [self didPlayToEnd];
            }
        }
    }
}


#pragma mark - target method
- (void)didPlayToEnd
{
    if (_delegate && [_delegate respondsToSelector:@selector(didPlayToEnd)]) {
        [_delegate didPlayToEnd];
    }
    [self stop];
}

/**
 *  耳机插入、拔出事件
 */
- (void)audioRouteChangeListenerCallback:(NSNotification*)notification
{
    NSDictionary *interuptionDict = notification.userInfo;
    
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    
    switch (routeChangeReason) {
            
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            // 耳机插入
            break;
            
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            // 耳机拔掉
            // 拔掉耳机继续播放
            [self.player play];
            break;
            
        case AVAudioSessionRouteChangeReasonCategoryChange:
            // called at start - also when other audio wants to play
            NSLog(@"AVAudioSessionRouteChangeReasonCategoryChange");
            break;
    }
}

- (void)displayLinkCallback:(CADisplayLink *)sender
{
    CMTime outputItemTime = kCMTimeInvalid;
    
    CFTimeInterval nextVSync = ([sender timestamp] + [sender duration]);
    
    outputItemTime = [self.videoOutPut itemTimeForHostTime:nextVSync];
    
    if ([self.videoOutPut hasNewPixelBufferForItemTime:outputItemTime]) {
        CVPixelBufferRef pixelBuffer = NULL;
        pixelBuffer = [self.videoOutPut copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
        if (!_isResetFrame) {
            _isResetFrame = YES;
            int frameWidth  = (int)CVPixelBufferGetWidth(pixelBuffer);
            int frameHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
            CGSize s = [self getNormalizedSamplingSize:CGSizeMake(frameWidth/2, frameHeight)];
            CGRect renderFrame = _renderView.frame;
            renderFrame.size.width = s.width;
            renderFrame.size.height = s.height;
            _renderView.frame = renderFrame;
            CGPoint centerPoint = _renderView.center;
            centerPoint.x = self.center.x;
            centerPoint.y = self.center.y;
            _renderView.center = centerPoint;
        }
        [self.renderView displayPixelBuffer:pixelBuffer];
        
        if (pixelBuffer != NULL) {
            CFRelease(pixelBuffer);
        }
    }
}

- (CGSize)getNormalizedSamplingSize:(CGSize)frameSize {
    CGFloat width = 0, height = 0;
    CGFloat videoH = frameSize.height;
    CGFloat videoW = frameSize.width;
    CGFloat sH = self.frame.size.height;
    CGFloat sW = self.frame.size.width;
    switch (self.contentMode) {
        case UIViewContentModeScaleAspectFit: {
            CGFloat a = videoH/sH;
            CGFloat b = videoW/sW;
            if (a>b) {
                height = sH;
                width = videoW/a;
            } else {
                height = videoH/b;
                width = sW;
            }
        }
            break;
        case UIViewContentModeScaleAspectFill: {
            CGFloat a = videoH/sH;
            CGFloat b = videoW/sW;
            if (a>b) {
                height = videoH/b;
                width = sW;
            } else {
                height = sH;
                width = videoW/a;
            }
        }
            break;
        case UIViewContentModeScaleToFill: {
            height = sH;
            width = sW;
        }
            break;
            
        default:
            break;
    }
    
    return CGSizeMake(width, height);
}

@end
