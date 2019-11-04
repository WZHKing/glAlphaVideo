//
//  AlphaVideoPlayerView.h
//  glAlphaVideo
//
//  Created by wzh on 2019/11/4.
//  Copyright © 2019 wzh. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol AlphaVideoPlayerViewProtocol <NSObject>
- (void)didPlayToEnd;
@end

@interface AlphaVideoPlayerView : UIView
@property(nonatomic, weak) id<AlphaVideoPlayerViewProtocol> delegate;
- (void)playWithURL:(NSURL *)url;
- (void)stop;
- (void)pause:(BOOL)paused;
@end
