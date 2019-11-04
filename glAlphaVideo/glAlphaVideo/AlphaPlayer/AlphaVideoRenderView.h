//
//  AlphaVideoRenderView.h
//  glAlphaVideo
//
//  Created by wzh on 2019/11/4.
//  Copyright © 2019 wzh. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AlphaVideoRenderView : UIView
/**
 display
 */
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end
