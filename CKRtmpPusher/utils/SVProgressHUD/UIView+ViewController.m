//
//  UIView+ViewController.m
//  WXMovie
//
//  Created by zsm on 14-5-30.
//  Copyright (c) 2014年 zsm. All rights reserved.
//

#import "UIView+ViewController.h"

@implementation UIView (ViewController)

//- (UIViewController *)viewController:(Class)class
- (UIViewController *)viewController
{
    //获取该视图的下一响应者（可能是控制器，也可能是父视图）
    id next = [self nextResponder];
    
    while (next != nil) {
        //判断next是否是控制器
        if ([next isKindOfClass:[UIViewController class]]) {
            return next;
        }
        
        //获取下一相应者
        next = [next nextResponder];
    }
    
    return nil;
}
@end
