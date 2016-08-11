//
//  GPUImageBeautifyFilter.m
//  BeautifyFaceTest
//
//  Created by Mac on 16/8/9.
//  Copyright © 2016年 bairuitech. All rights reserved.
//

#import "GPUImageBeautifyFilter.h"
/***************************************************/
// Internal CombinationFilter(It should not be used outside)
@interface GPUImageCombinationFilter : GPUImageThreeInputFilter//三输入的滤波器
{
    GLint smoothDegreeUniform;
}

@property (nonatomic, assign) CGFloat intensity;

@end
//Shader着色器
//Shader出现在OpenGL ES 2.0中，允许创建自己的Shader。必须同时创建两个Shader，分别是Vertex shader和Fragment shader.http://www.jianshu.com/p/8687a040eb48
NSString *const kGPUImageBeautifyFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 varying highp vec2 textureCoordinate2;
 varying highp vec2 textureCoordinate3;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 uniform sampler2D inputImageTexture3;
 uniform mediump float smoothDegree;
 
 void main()
 {
     highp vec4 bilateral = texture2D(inputImageTexture, textureCoordinate);
     highp vec4 canny = texture2D(inputImageTexture2, textureCoordinate2);
     highp vec4 origin = texture2D(inputImageTexture3,textureCoordinate3);
     highp vec4 smooth;
     lowp float r = origin.r;
     lowp float g = origin.g;
     lowp float b = origin.b;
     if (canny.r < 0.2 && r > 0.3725 && g > 0.1568 && b > 0.0784 && r > b && (max(max(r, g), b) - min(min(r, g), b)) > 0.0588 && abs(r-g) > 0.0588) {
         smooth = (1.0 - smoothDegree) * (origin - bilateral) + bilateral;
     }
     else {
         smooth = origin;
     }
     smooth.r = log(1.0 + 0.2 * smooth.r)/log(1.2);
     smooth.g = log(1.0 + 0.2 * smooth.g)/log(1.2);
     smooth.b = log(1.0 + 0.2 * smooth.b)/log(1.2);
     gl_FragColor = smooth;
 }
 );

@implementation GPUImageCombinationFilter

- (id)init {
    if (self = [super initWithFragmentShaderFromString:kGPUImageBeautifyFragmentShaderString]) {
        smoothDegreeUniform = [filterProgram uniformIndex:@"smoothDegree"];
    }
    self.intensity = 0.5;
    return self;
}

- (void)setIntensity:(CGFloat)intensity {
    _intensity = intensity;
    [self setFloat:intensity forUniform:smoothDegreeUniform program:filterProgram];
}

@end

/***************************************************/
@implementation GPUImageBeautifyFilter//美颜滤镜
-(instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    //1.双边模糊
    bilateralFilter = [[GPUImageBilateralFilter alloc] init];
    bilateralFilter.distanceNormalizationFactor = 4.0;
    [self addFilter:bilateralFilter];
    //2.边缘探测
    cannyEdgeFilter = [[GPUImageCannyEdgeDetectionFilter alloc] init];
    [self addFilter:cannyEdgeFilter];
    //3.合并
    combinationFilter = [[GPUImageCombinationFilter alloc] init];
    [self addFilter:combinationFilter];
    //4.调整HSB
    hsbFilter = [[GPUImageHSBFilter alloc] init];
    [hsbFilter adjustBrightness:1.1];//亮度
    [hsbFilter adjustSaturation:1.1];//饱和度
    
    [bilateralFilter addTarget:combinationFilter];
    [cannyEdgeFilter addTarget:combinationFilter];
    
    [combinationFilter addTarget:hsbFilter];
    self.initialFilters = [NSArray arrayWithObjects:bilateralFilter,cannyEdgeFilter,combinationFilter, nil];
    self.terminalFilter = hsbFilter;
    return self;
}
#pragma mark GPUImageInput protocol

-(void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex {
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters) {
        if (currentFilter != self.inputFilterToIgnoreForUpdates) {
            if (currentFilter == combinationFilter) {
                textureIndex = 2;
            }
            [currentFilter newFrameReadyAtTime:frameTime atIndex:textureIndex];
        }
    }
}
-(void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex {
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters) {
        if (currentFilter != self.inputFilterToIgnoreForUpdates) {
            if (currentFilter == combinationFilter) {
                textureIndex = 2;
            }
            [currentFilter setInputFramebuffer:newInputFramebuffer atIndex:textureIndex];
        }

    }
}
@end

/*
 1、GPUImageVideoCamera捕获摄像头图像
 调用newFrameReadyAtTime: atIndex:通知GPUImageBeautifyFilter；
 
 2、GPUImageBeautifyFilter调用newFrameReadyAtTime: atIndex:
 通知GPUImageBilateralFliter输入纹理已经准备好；
 
 3、GPUImageBilateralFliter 绘制图像后在informTargetsAboutNewFrameAtTime()，
 调用setInputFramebufferForTarget: atIndex:
 把绘制的图像设置为GPUImageCombinationFilter输入纹理，
 并通知GPUImageCombinationFilter纹理已经绘制完毕；
 
 4、GPUImageBeautifyFilter调用newFrameReadyAtTime: atIndex:
 通知 GPUImageCannyEdgeDetectionFilter输入纹理已经准备好；
 
 5、同3，GPUImageCannyEdgeDetectionFilter 绘制图像后，
 把图像设置为GPUImageCombinationFilter输入纹理；
 
 6、GPUImageBeautifyFilter调用newFrameReadyAtTime: atIndex:
 通知 GPUImageCombinationFilter输入纹理已经准备好；
 
 7、GPUImageCombinationFilter判断是否有三个纹理，三个纹理都已经准备好后
 调用GPUImageThreeInputFilter的绘制函数renderToTextureWithVertices: textureCoordinates:，
 图像绘制完后，把图像设置为GPUImageHSBFilter的输入纹理,
 通知GPUImageHSBFilter纹理已经绘制完毕；
 
 8、GPUImageHSBFilter调用renderToTextureWithVertices: textureCoordinates:绘制图像，
 完成后把图像设置为GPUImageView的输入纹理，并通知GPUImageView输入纹理已经绘制完毕；
 
 9、GPUImageView把输入纹理绘制到自己的帧缓存，然后通过
 [self.context presentRenderbuffer:GL_RENDERBUFFER];显示到UIView上。
 */
