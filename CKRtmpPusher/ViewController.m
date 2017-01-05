//
//  ViewController.m
//  CKRtmpPusher
//
//  Created by sandy on 2017/1/5.
//  Copyright © 2017年 concox. All rights reserved.
//

#import "ViewController.h"
#import "SVProgressHUD.h"

#import "LiveViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    // Do any additional setup after loading the view, typically from a nib.
    
    UIButton *but = [UIButton buttonWithType:UIButtonTypeCustom];
    but.frame = CGRectMake(100, 100, (kScreenWidth-100) / 2, 64);
    but.layer.cornerRadius = 5.f;
    but.layer.borderColor = [[UIColor redColor]CGColor];
    but.layer.borderWidth = 5.f;
    [but setTitle:@"开始推流" forState:UIControlStateNormal];
    [but addTarget:self action:@selector(start_push) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:but];
}

- (void)start_push
{
    [SVProgressHUD showWithStatus:@"loading..."];
    LiveViewController *live = [[LiveViewController alloc]init];
    [self.navigationController pushViewController:live animated:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - 横竖屏控制
- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}


@end
