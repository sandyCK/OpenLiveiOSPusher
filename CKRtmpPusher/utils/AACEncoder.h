//
//  AACEncoder.h
//  CKRTSPClient
//
//  Created by sandy on 2016/12/19.
//  Copyright © 2016年 concox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface AACEncoder : NSObject

- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer completionBlock:(void (^)(char *encodedData, int data_size, NSError* error, uint32_t timeStamp)) completionBlock;

@end
