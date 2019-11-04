//
//  AlphaVideoRenderView.m
//  glAlphaVideo
//
//  Created by wzh on 2019/11/4.
//  Copyright © 2019 wzh. All rights reserved.
//

#import "AlphaVideoRenderView.h"
#import <OpenGLES/ES2/glext.h>
#import <GLKit/GLKit.h>

enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};

//纹理坐标
GLfloat quadTextureData[] = {
    0.5f, 1.0f,
    0.5f, 0.0f,
    1.0f, 1.0f,
    1.0f, 0.0f,
};

//顶点坐标
GLfloat quadVertexData[] = {
    -1.0f, 1.0f,
    -1.0f, -1.0f,
    1.0f, 1.0f,
    1.0f, -1.0f,
};

@interface AlphaVideoRenderView()
{
    GLint _backingWidth;
    GLint _backingHeight;
    
    EAGLContext *_context;
    CVOpenGLESTextureCacheRef _videoTextureCache; //纹理缓存
    
    GLuint _frameBufferHandle;
    GLuint _colorBufferHandle;
    
    // RGB
    GLuint                  _rgbProgram;
    CVOpenGLESTextureRef    _renderTexture;
    GLint                   _displayInputTextureUniform;
}

@property (nonatomic, assign) CGFloat   pixelbufferWidth;
@property (nonatomic, assign) CGFloat   pixelbufferHeight;
@end

@implementation AlphaVideoRenderView

#pragma mark - life cycle
- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self commonInit];
    }
    return self;
}

- (void)dealloc {
    [self cleanUpTextures];
    
    if(_videoTextureCache) {
        CFRelease(_videoTextureCache);
    }
}

#pragma mark - public methods
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    [self displayPixelBuffer:pixelBuffer
           videoTextureCache:_videoTextureCache
                     context:_context
                backingWidth:_backingWidth
               backingHeight:_backingHeight
           frameBufferHandle:_frameBufferHandle
                  rgbProgram:_rgbProgram
  displayInputTextureUniform:_displayInputTextureUniform
           colorBufferHandle:_colorBufferHandle];
}

#pragma mark - private methods
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (void)commonInit {
    self.userInteractionEnabled = NO;
    self.pixelbufferWidth = 0;
    self.pixelbufferHeight = 0;
    
    _context = [self createOpenGLContextWithWidth:&_backingWidth
                                           height:&_backingHeight
                                videoTextureCache:&_videoTextureCache
                                colorBufferHandle:&_colorBufferHandle
                                frameBufferHandle:&_frameBufferHandle];
}

#pragma mark Render
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer
         videoTextureCache:(CVOpenGLESTextureCacheRef)videoTextureCache
                   context:(EAGLContext *)context
              backingWidth:(GLint)backingWidth
             backingHeight:(GLint)backingHeight
         frameBufferHandle:(GLuint)frameBufferHandle
                rgbProgram:(GLuint)rgbProgram
displayInputTextureUniform:(GLuint)displayInputTextureUniform colorBufferHandle:(GLuint)colorBufferHandle{
    if (pixelBuffer == NULL) {
        return;
    }
    
    int frameWidth  = (int)CVPixelBufferGetWidth(pixelBuffer);
    int frameHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
    
    if (!videoTextureCache) {
        NSLog(@"No video texture cache");
        return;
    }
    if ([EAGLContext currentContext] != context) {
        [EAGLContext setCurrentContext:context];
    }
    
    [self cleanUpTextures];
    
    CVOpenGLESTextureRef renderTexture;
    
    // 创建亮度纹理
    // 激活纹理单元0, 不激活，创建纹理会失败
    glActiveTexture(GL_TEXTURE0);
    // 创建纹理对象
    CVReturn error;
    error = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                         videoTextureCache,
                                                         pixelBuffer,
                                                         NULL,
                                                         GL_TEXTURE_2D,
                                                         GL_RGBA,
                                                         frameWidth,
                                                         frameHeight,
                                                         GL_BGRA,
                                                         GL_UNSIGNED_BYTE,
                                                         0,
                                                         &renderTexture);
    if (error) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", error);
    }else {
        _renderTexture = renderTexture;
    }
    //获取纹理对象  CVOpenGLESTextureGetName(renderTexture)
    //绑定纹理
    glBindTexture(CVOpenGLESTextureGetTarget(renderTexture), CVOpenGLESTextureGetName(renderTexture));
    
    //设置纹理滤波
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    //设置视口大小
    glViewport(0, 0, backingWidth, backingHeight);
    //设置一个RGB颜色和透明度，接下来会用这个颜色涂满全屏
    glClearColor(1.0f, 1.0f, 1.0f, 0.0f);
    //清除颜色缓冲区
    glClear(GL_COLOR_BUFFER_BIT);
    
    //启动程序
    glUseProgram(rgbProgram);
    // 在创建纹理之前，有激活过纹理单元，glActiveTexture(GL_TEXTURE0)
    // 指定着色器中亮度纹理对应哪一层纹理单元
    // 这样就会把亮度纹理，往着色器上贴
    glUniform1i(displayInputTextureUniform, 0);
    
    if (self.pixelbufferWidth != frameWidth || self.pixelbufferHeight != frameHeight) {
        CGSize normalizedSamplingSize = CGSizeMake(1.0, 1.0);
        self.pixelbufferWidth = frameWidth;
        self.pixelbufferHeight = frameHeight;
        
        // 左下角
        quadVertexData[0] = -1 * normalizedSamplingSize.width;
        quadVertexData[1] = -1 * normalizedSamplingSize.height;
        // 左上角
        quadVertexData[2] = -1 * normalizedSamplingSize.width;
        quadVertexData[3] = normalizedSamplingSize.height;
        // 右下角
        quadVertexData[4] = normalizedSamplingSize.width;
        quadVertexData[5] = -1 * normalizedSamplingSize.height;
        // 右上角
        quadVertexData[6] = normalizedSamplingSize.width;
        quadVertexData[7] = normalizedSamplingSize.height;
    }
    
    //激活ATTRIB_VERTEX顶点数组
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    //给ATTRIB_VERTEX顶点数组赋值
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, quadVertexData);
    
    //激活ATTRIB_TEXCOORD顶点数组
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    //给ATTRIB_TEXCOORD顶点数组赋值
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, 0, 0, quadTextureData);
    
    //渲染纹理数据
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    /// 把上下文的东西渲染到屏幕上
    if ([EAGLContext currentContext] == context) {
        [context presentRenderbuffer:GL_RENDERBUFFER];
    }
}

- (EAGLContext *)createOpenGLContextWithWidth:(int *)width height:(int *)height videoTextureCache:(CVOpenGLESTextureCacheRef *)videoTextureCache colorBufferHandle:(GLuint *)colorBufferHandle frameBufferHandle:(GLuint *)frameBufferHandle {
    //设置比例因子
    self.contentScaleFactor = [[UIScreen mainScreen] scale];
    //设置图层
    CAEAGLLayer *eaglLayer       = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = NO; //这个一定要设置  不然无法透明
    eaglLayer.backgroundColor = [UIColor clearColor].CGColor;
    /*kEAGLDrawablePropertyRetainedBacking  是否需要保留已经绘制到图层上面的内容
     kEAGLDrawablePropertyColorFormat 绘制对象内部的颜色缓冲区的格式 kEAGLColorFormatRGBA8 4*8 = 32*/
    eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking : [NSNumber numberWithBool:NO],
                                     kEAGLDrawablePropertyColorFormat     : kEAGLColorFormatRGBA8};
    //设置上下文
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:context];
    
    [self setupBuffersWithContext:context
                            width:width
                           height:height
                colorBufferHandle:colorBufferHandle
                frameBufferHandle:frameBufferHandle];
    //加载着色器
    [self loadShader];
    
    if (!*videoTextureCache) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, context, NULL, videoTextureCache);
        if (err != noErr) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d",err);
        }
    }
    
    return context;
}

- (void)setupBuffersWithContext:(EAGLContext *)context width:(int *)width height:(int *)height colorBufferHandle:(GLuint *)colorBufferHandle frameBufferHandle:(GLuint *)frameBufferHandle {
    //创建渲染缓存
    glGenRenderbuffers(1, colorBufferHandle);
    glBindRenderbuffer(GL_RENDERBUFFER, *colorBufferHandle);
    
    // 把渲染缓存绑定到渲染图层上CAEAGLLayer，并为它分配一个共享内存。
    // 并且会设置渲染缓存的格式，和宽度
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    //获取 width & height
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH , width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, height);
    
    //创建帧缓存
    glGenFramebuffers(1, frameBufferHandle);
    glBindFramebuffer(GL_FRAMEBUFFER, *frameBufferHandle);
    // 把颜色渲染缓存 添加到 帧缓存的GL_COLOR_ATTACHMENT0上,就会自动把渲染缓存的内容填充到帧缓存，在由帧缓存渲染到屏幕
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, *colorBufferHandle);
}

- (void)loadShader{
    GLuint vertShader, fragShader; //定义顶点着色器和片元着色器两个临时对象
    NSURL  *vertShaderURL, *fragShaderURL; //两个着色器bundle地址url
    NSString *shaderName = @"gift_glsl";
    
    //编译shader
    vertShaderURL = [[NSBundle mainBundle] URLForResource:shaderName withExtension:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER URL:vertShaderURL]) {
        NSLog(@"Failed to compile vertex shader");
        return;
    }
    
    fragShaderURL = [[NSBundle mainBundle] URLForResource:shaderName withExtension:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER URL:fragShaderURL]) {
        NSLog(@"Failed to compile fragment shader");
        return;
    }
    
    //创建一个着色器程序对象
    GLuint program = glCreateProgram();
    _rgbProgram = program;
    
    //关联着色器对象到着色器程序对象
    //绑定顶点着色器
    glAttachShader(program, vertShader);
    //绑定片元着色器
    glAttachShader(program, fragShader);
    
    // 绑定着色器属性,方便以后获取，以后根据角标获取
    // 一定要在链接程序之前绑定属性,否则拿不到
    glBindAttribLocation(program, ATTRIB_VERTEX  , "Position");
    glBindAttribLocation(program, ATTRIB_TEXCOORD, "TextureCoords");
    
    //链接程序
    if (![self linkProgram:program]) {
        //链接失败释放vertShader\fragShader\program
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (program) {
            glDeleteProgram(program);
            program = 0;
        }
        return;
    }
    
    /// 获取全局参数,注意 一定要在连接完成后才行，否则拿不到
    _displayInputTextureUniform = glGetUniformLocation(program, "Texture");
    
    //释放已经使用完毕的verShader\fragShader
    if (vertShader) {
        glDetachShader(program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(program, fragShader);
        glDeleteShader(fragShader);
    }
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type URL:(NSURL *)URL {
    NSError *error;
    NSString *sourceString = [[NSString alloc] initWithContentsOfURL:URL
                                                            encoding:NSUTF8StringEncoding
                                                               error:&error];
    if (sourceString == nil) {
        NSLog(@"Failed to load vertex shader: %s", [error localizedDescription].UTF8String);
        return NO;
    }
    
    GLint status;
    const GLchar *source;
    source = (GLchar *)[sourceString UTF8String];
    
    *shader = glCreateShader(type); // 创建着色器
    glShaderSource(*shader, 1, &source, NULL);//加载着色器源代码
    glCompileShader(*shader); //编译着色器
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);//获取完成状态
    if (status == 0) {
        // 没有完成就直接删除着色器
        glDeleteShader(*shader);
        return NO;
    }
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog {
    GLint status;
    glLinkProgram(prog);// 链接程序
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);//获取完成状态
    if (status == 0) {
        return NO;
    }
    return YES;
}

#pragma mark Clean

- (void)cleanUpTextures {
    if (_renderTexture) {
        CFRelease(_renderTexture);
        _renderTexture = NULL;
    }
    // 清空纹理缓存
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
}

@end
