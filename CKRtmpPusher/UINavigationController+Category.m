//
//  UINavigationController+Category.m
//  FfmpegLib
//
//  Created by sandy on 2016/10/18.
//  Copyright © 2016年 concox. All rights reserved.
//

#import "UINavigationController+Category.h"

@interface UINavigationController ()

@end

@implementation UINavigationController (Category)

- (BOOL)shouldAutorotate
{
    return self.topViewController.shouldAutorotate;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return self.topViewController.supportedInterfaceOrientations;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return self.topViewController.preferredInterfaceOrientationForPresentation;
}

@end
