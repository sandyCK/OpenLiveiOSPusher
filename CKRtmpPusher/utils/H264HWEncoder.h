//
//  H264HWEncoder.h
//  CKRTSPClient
//
//  Created by sandy on 2016/12/16.
//  Copyright © 2016年 concox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol H264HWEncoderDelegate <NSObject>

- (void)H264HWEncoder_GotEncodedData: (char *)data length: (uint32_t)length
                              pts_ms: (uint32_t)pts
                          isKeyframe: (BOOL)isKey;

- (void)H264HWEncoder_GotSpsPps : (const uint8_t *)sps sps_length: (size_t)sps_length
                             pps: (const uint8_t *)pps pps_length:(size_t)pps_length
                          pts_ms: (uint32_t)pts;

@end

@interface H264HWEncoder : NSObject

- (instancetype)initWithWidth: (int)width height: (int)height bit_rate: (unsigned long)bit_rate frame_rate: (int)fps;
- (void)encode: (CMSampleBufferRef)buffer;

@property (nonatomic, weak)id<H264HWEncoderDelegate> delegate;

@end
