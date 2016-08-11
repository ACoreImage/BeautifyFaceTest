//
//  GPUImageBeautifyFilter.h
//  BeautifyFaceTest
//
//  Created by Mac on 16/8/9.
//  Copyright © 2016年 bairuitech. All rights reserved.
//

#import <GPUImage/GPUImage.h>
@class GPUImageCombinationFilter;
@interface GPUImageBeautifyFilter : GPUImageFilterGroup
//Combination  Filter是我们自己定义的三输入的滤波器。三个输入分别是原图像A(x, y),双边滤波后的图像B(x, y），边缘图像C(x, y)。其中A,B,C可以看成是图像矩阵，(x,y)可以看成其中某一像素的坐标。
{
    GPUImageBilateralFilter *bilateralFilter; //双边模糊
    GPUImageCannyEdgeDetectionFilter *cannyEdgeFilter;//Canny边缘检测算法
    GPUImageHSBFilter *hsbFilter;//HSB颜色滤镜
    GPUImageCombinationFilter *combinationFilter;//滤镜的组合
}

@end
