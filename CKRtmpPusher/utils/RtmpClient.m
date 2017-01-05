//
//  RtmpClient.m
//  CKRTSPClient
//
//  Created by sandy on 2017/1/4.
//  Copyright © 2017年 concox. All rights reserved.
//

#import "RtmpClient.h"
#import "srs_librtmp.h"

@implementation RtmpClient
{
    srs_rtmp_t rtmp;
}

- (instancetype)init
{
    if (self = [super init]) {
        /* init rtmp */
        rtmp = NULL;
        rtmp = srs_rtmp_create("rtmp://10.0.12.118/live/cktest");
        if (rtmp == NULL) {
            srs_human_trace("Could not create rtmp!");
            return nil;
        }
        
        if (srs_rtmp_handshake(rtmp) != 0) {
            srs_human_trace("simple handshake failed.");
            return nil;
        }
        
        if (srs_rtmp_connect_app(rtmp) != 0) {
            srs_human_trace("connect vhost/app failed.");
            return nil;
        }
        
        if (srs_rtmp_publish_stream(rtmp) != 0) {
            srs_human_trace("publish stream failed.");
            return nil;
        }
    }
    return self;
}

- (BOOL)write_h264_raw_frame: (uint8_t *)frame data_size: (int)frames_size pts:(uint32_t)pts dts: (uint32_t)dts
{
    @synchronized (self) {
        int ret = srs_h264_write_raw_frames(rtmp, frame, frames_size, dts, pts);
        if (ret != 0) {
            if (srs_h264_is_dvbsp_error(ret)) {
                srs_human_trace("data--->ignore drop video error, code=%d!", ret);
            } else if (srs_h264_is_duplicated_pps_error(ret)) {
                srs_human_trace("data--->srs_h264_is_duplicated_pps_error, code=%d!", ret);
            } else if (srs_h264_is_duplicated_sps_error(ret)) {
                srs_human_trace("data--->srs_h264_is_duplicated_sps_error, code=%d!", ret);
            } else {
                srs_human_trace("send h264 raw data failed. ret=%d", ret);
                return NO;
            }
        } else
            NSLog(@"write video frame success!");
        return YES;
    }
}

- (BOOL)write_aac_raw_frame: (char *)frame data_size: (int)data_size
               sound_format: (char)sound_format sound_rate: (char)sound_rate
                 sound_size: (char)sound_size sound_type: (char)sound_type timestamp: (uint32_t)timestamp
{
    @synchronized (self) {
        int ret = srs_audio_write_raw_frame(rtmp, sound_format, sound_rate, sound_size, sound_type, frame, data_size, timestamp);
        if (ret == 0) {
            NSLog(@"write audio frame success!");
            return YES;
        } else
            NSLog(@"write audio frame failed!!!");
        return NO;
    }
}

- (void)dealloc
{
    NSLog(@"%s", __FUNCTION__);
    if (rtmp) {
        srs_rtmp_destroy(rtmp);
        rtmp = NULL;
    }
}

@end
