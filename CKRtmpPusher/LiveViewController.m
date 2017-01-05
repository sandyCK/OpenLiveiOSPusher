//
//  LiveViewController.m
//  CKRTSPClient
//
//  Created by sandy on 2016/12/16.
//  Copyright © 2016年 concox. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "LiveViewController.h"
#import "H264HWEncoder.h"
#import "AACEncoder.h"
#import "RtmpClient.h"

#import "SVProgressHUD.h"

const int frame_rate = 15;

typedef enum : NSUInteger {
    VideoBitRateHigh = 1000*1024,   // 125Kbyte/s
    VideoBitRateMedium = 480*1024,  //  60Kbyte/s
    VideoBitRateLow = 120*1024,     //  15Kbyte/s
} VideoBitRate;

const char NALU_Header[] = "\x00\x00\x00\x01";

@interface LiveViewController () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, H264HWEncoderDelegate>

@property (nonatomic, strong)AVCaptureSession *session;

@property (nonatomic, strong)UIImageView *showImgView;

@property (nonatomic, strong)AVCaptureDeviceInput *frontCamera;
@property (nonatomic, strong)AVCaptureDeviceInput *backCamera;
@property (nonatomic, strong)AVCaptureDeviceInput *currentCamera;

@property (nonatomic, strong)AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong)AVCaptureAudioDataOutput *audioOutput;
@property (nonatomic, strong)AVCaptureConnection *videoConnection;
@property (nonatomic, strong)AVCaptureConnection *audioConnection;
@property (nonatomic, strong)dispatch_queue_t m_queue;
@property (nonatomic, strong)AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, assign)UIDeviceOrientation startOrientation;// 视频录制开始时的方向
@property (nonatomic, assign)uint32_t first_pts;

@end

@implementation LiveViewController
{
    H264HWEncoder *h264_encoder;
    AACEncoder *aac_encoder;

    RtmpClient *rtmp;
    uint8_t *nalu_spspps;
    size_t nalu_spspps_length;
    BOOL spspps_is_written;
}

#pragma mark - life cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = @"Live";
    [self InitNavigationBar];
    [self initShowUI];
    
    /* init camera */
    _session = [[AVCaptureSession alloc] init];// 初始化AVCaptureSession
    [self.session setSessionPreset:AVCaptureSessionPreset640x480];// 设置分辨率
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    self.frontCamera = [AVCaptureDeviceInput deviceInputWithDevice:videoDevices.lastObject error:nil];
    self.backCamera = [AVCaptureDeviceInput deviceInputWithDevice:videoDevices.firstObject error:nil];
    
    //配置采集输出
    _m_queue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoOutput setSampleBufferDelegate:self queue:_m_queue];
    
    _audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [_audioOutput setSampleBufferDelegate:self queue:_m_queue];
    
    if (![self initCamera:NO]) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        /* init rtmp */
        rtmp = [[RtmpClient alloc]init];
        if (!rtmp) {
            [SVProgressHUD dismissWithError:@"无法连接服务器，请检查网络连接" afterDelay:2.0];
            [self navLeftBtnAction];
            return;
        }
        
        /* init h264 hardware encoder */
        h264_encoder = [[H264HWEncoder alloc]initWithWidth:640 height:480 bit_rate:VideoBitRateLow frame_rate:frame_rate];
        h264_encoder.delegate = self;
        if (!h264_encoder) {
            [SVProgressHUD dismissWithError:@"初始化h264编码器失败" afterDelay:2.0];
            [self navLeftBtnAction];
            return;
        }
        
        /* init aac hardware encoder */
        aac_encoder = [[AACEncoder alloc]init];
        if (!aac_encoder) {
            [SVProgressHUD dismissWithError:@"初始化aac编码器失败" afterDelay:2.0];
            [self navLeftBtnAction];
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
            _first_pts = 0;
            nalu_spspps = NULL;
            nalu_spspps_length = 0;
            spspps_is_written = NO;
        });
    });
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    self.navigationController.navigationBarHidden = YES;
    [self.session startRunning];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:YES];
    self.navigationController.navigationBarHidden = NO;
}

- (void)dealloc
{
    NSLog(@"%s", __FUNCTION__);
    if (nalu_spspps) {
        free(nalu_spspps);
        nalu_spspps = NULL;
    }
    
    rtmp = nil;
    h264_encoder = nil;
    aac_encoder = nil;
}

#pragma mark - pravite methods
- (NSString *)getPathForDocumentsResourceDic:(NSString *)relativePathDic
{
    NSString *documentsPath = nil;
    if (nil == documentsPath) {
        NSArray* dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        documentsPath = [dirs objectAtIndex:0];
    }
    
    NSString *str = [documentsPath stringByAppendingString:relativePathDic];
    if (![[NSFileManager defaultManager] fileExistsAtPath:str]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:str withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return str;
}

- (void)InitNavigationBar
{
    UIView *statusView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, kScreenWidth, kStatusBarHeight)];
    statusView.backgroundColor = ZJColorFromRGB(0x019d92);
    [self.view addSubview:statusView];
    
    UIView *navView = [[UIView alloc]initWithFrame:CGRectMake(0, kStatusBarHeight, kScreenWidth, kNavigationHeight)];
    navView.backgroundColor = ZJColorFromRGB(0x019d92);
    [self.view addSubview:navView];
    
    UIFont *titleFont = [UIFont systemFontOfSize:18];
    CGSize size = [self.title sizeWithAttributes:@{NSFontAttributeName:titleFont}];
    UILabel *titleLabel = [[UILabel alloc]initWithFrame:CGRectMake((navView.frame.size.width - size.width) / 2, (navView.frame.size.height - size.height) / 2, size.width, size.height)];
    titleLabel.text = self.title;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 0;
    titleLabel.font = titleFont;
    titleLabel.textColor = [UIColor whiteColor];
    [navView addSubview:titleLabel];
    
    UIImage *backImg = [UIImage imageNamed:@"icon_back_no"];
    UIButton *backBut = [[UIButton alloc] initWithFrame:CGRectMake(10, 7.5f, backImg.size.width, backImg.size.width)];
    [backBut setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBut setBackgroundImage:[UIImage imageNamed:@"icon_back_sel"] forState:UIControlStateHighlighted];
    [backBut setBackgroundColor:[UIColor clearColor]];
    [backBut addTarget:self action:@selector(navLeftBtnAction) forControlEvents:UIControlEventTouchUpInside];
    [navView addSubview:backBut];
    
    UIImage *switchImg = [UIImage imageNamed:@"camera_switch"];
    UIButton *switchCamera = [UIButton buttonWithType:UIButtonTypeCustom];
    switchCamera.frame = CGRectMake(kScreenWidth-switchImg.size.width-10, 7.5f, switchImg.size.width, switchImg.size.width);
    [switchCamera setBackgroundImage:[UIImage imageNamed:@"camera_switch"] forState:UIControlStateNormal];
    [switchCamera setBackgroundColor:[UIColor clearColor]];
    [switchCamera addTarget:self action:@selector(switch_camera) forControlEvents:UIControlEventTouchUpInside];
    [navView addSubview:switchCamera];
}

- (void)navLeftBtnAction
{
    [_session stopRunning];
    [_previewLayer removeFromSuperlayer];
    
    [self.navigationController popViewControllerAnimated:YES];
}
    
- (BOOL)initCamera: (BOOL)isFront
{
    if (isFront) {
        self.currentCamera = self.frontCamera;
    } else
        self.currentCamera = self.backCamera;
    
    /* 添加输入设备 */
    NSError *error = nil;
    [self.currentCamera.device lockForConfiguration:nil];
    
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    error = nil;
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if (error) {
        NSLog(@"failed getting audio input device: %@", error.description);
        return NO;
    }
    
    //添加到Session
    if ([self.session canAddInput:self.currentCamera]) {
        [self.session addInput:self.currentCamera];
    }
    if ([self.session canAddInput:audioInput]) {
        [self.session addInput:audioInput];
    }
    
    //配置输出视频的图像格式
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey, nil];
    
    _videoOutput.videoSettings = settings;
    _videoOutput.alwaysDiscardsLateVideoFrames = YES;
    if ([_session canAddOutput:_videoOutput]) {
        [_session addOutput:_videoOutput];
    } else
        return NO;
    
    if ([_session canAddOutput:_audioOutput]) {
        [_session addOutput:_audioOutput];
    } else
        return NO;

    // 设置帧率
    self.currentCamera.device.activeVideoMinFrameDuration = CMTimeMake(1, frame_rate);
    self.currentCamera.device.activeVideoMaxFrameDuration = CMTimeMake(1, frame_rate);
    
    if (!_previewLayer) {
        _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
        _previewLayer.frame = self.showImgView.layer.bounds;
        _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill; // 设置预览时的视频缩放方式
        [_previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortrait]; // 设置视频的朝向
    }
    
    [self.showImgView.layer addSublayer:_previewLayer];
    
    return YES;
}
    
- (void)initShowUI
{
    _showImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, kNavigationHeight + kStatusBarHeight, kScreenWidth, kScreenHeight - kNavigationHeight - kStatusBarHeight)];
    [self.view addSubview:_showImgView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)switch_camera
{
    [self.session stopRunning];
    [_previewLayer removeFromSuperlayer];
    [self.session beginConfiguration];
    
    [self.session removeInput:self.currentCamera];
    [self.session removeOutput:_videoOutput];
    if (self.currentCamera == self.backCamera) {
        self.currentCamera = self.frontCamera;
    } else
        self.currentCamera = self.backCamera;
    
    [self.session addInput:self.currentCamera];
    [self.session addOutput:_videoOutput];
    
    self.currentCamera.device.activeVideoMinFrameDuration = CMTimeMake(1, frame_rate);
    self.currentCamera.device.activeVideoMaxFrameDuration = CMTimeMake(1, frame_rate);
    
    [self.session commitConfiguration];
    [self.showImgView.layer addSublayer:_previewLayer];
    [self.session startRunning];
    
    CATransition *transition = [CATransition animation];
    transition.duration = 1.0;
    transition.type = @"rippleEffect";
    transition.subtype = kCATransitionFromRight;
    [self.showImgView.layer addAnimation:transition forKey:nil];
}
    
#pragma mark - AVCapture data output sampleBuffer delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    __weak typeof(self) weakself = self;
    
    if (connection == [_videoOutput connectionWithMediaType:AVMediaTypeVideo]) {
        
        [h264_encoder encode:sampleBuffer];
        
    } else if (connection == [_audioOutput connectionWithMediaType:AVMediaTypeAudio]) {
        
        [aac_encoder encodeSampleBuffer:sampleBuffer completionBlock:^(char *encodedData, int data_size, NSError *error, uint32_t timeStamp) {
            if (error) {
                NSLog(@"aac encode failed--->%@", error.localizedDescription);
            } else {
                BOOL ret = [rtmp write_aac_raw_frame:encodedData data_size:data_size sound_format:10 sound_rate:3 sound_size:16 sound_type:0 timestamp:timeStamp];
                
                free(encodedData);
                encodedData = NULL;
                
                if (!ret) {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [weakself navLeftBtnAction];
                    });
                }
            }
        }];
        
    }
}

#pragma mark - H264HWEncoderDelegate
- (void)H264HWEncoder_GotSpsPps : (const uint8_t *)sps sps_length:(size_t)sps_length pps:(const uint8_t *)pps pps_length:(size_t)pps_length pts_ms:(uint32_t)pts
{
    
    /* add NALU header */
    if (!nalu_spspps) {
        nalu_spspps_length = sps_length + pps_length + 8;
        nalu_spspps = (uint8_t *)malloc(nalu_spspps_length);
        memset(nalu_spspps, 0, nalu_spspps_length);
        memcpy(nalu_spspps, NALU_Header, 4);
        memcpy(nalu_spspps+4, sps, sps_length);
        memcpy(nalu_spspps+4+sps_length, NALU_Header, 4);
        memcpy(nalu_spspps+8+sps_length, pps, pps_length);
    }
}

- (void)H264HWEncoder_GotEncodedData: (char *)data length: (uint32_t)length pts_ms:(uint32_t)pts isKeyframe:(BOOL)isKey
{
    /* calculate pts */
    uint32_t pts_cal;
    if (self.first_pts == 0) {
        self.first_pts = pts;
        pts_cal = 0;
    } else {
        pts_cal = pts - self.first_pts;
    }
    
    if (!spspps_is_written && isKey) {
        if ([rtmp write_h264_raw_frame:nalu_spspps data_size:(int)nalu_spspps_length pts:pts_cal dts:pts_cal]) {
            spspps_is_written = YES;
        }
    }
    
    uint8_t nalu_data[length+3];
    memcpy(nalu_data, NALU_Header, 4);
    memcpy(nalu_data + 4, data, length);
    if (![rtmp write_h264_raw_frame:nalu_data data_size:length+4 pts:pts_cal dts:pts_cal]) {
        __weak typeof(self) weakself = self;
        dispatch_sync(dispatch_get_main_queue(), ^{
            [weakself navLeftBtnAction];
        });
    }
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
