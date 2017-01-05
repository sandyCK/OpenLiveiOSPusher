//
//  H264HWEncoder.m
//  CKRTSPClient
//
//  Created by sandy on 2016/12/16.
//  Copyright © 2016年 concox. All rights reserved.
//

#import "H264HWEncoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface H264HWEncoder ()

@property (nonatomic, assign)uint32_t frame_rate;

@end

@implementation H264HWEncoder
{
    dispatch_queue_t queue;
    int frameCount;
    VTCompressionSessionRef EncodingSession;
    BOOL got_spspps;
}

// 编码回调，每当系统编码完一帧之后，会异步掉用该方法，此为c语言方法
static void output_callback(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer )
{
//    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != 0) return;
    
    if (!CMSampleBufferDataIsReady(sampleBuffer))
    {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    H264HWEncoder* encoder = (__bridge H264HWEncoder*)outputCallbackRefCon;
    
    // Check if we have got a key frame first
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    if (keyframe && !encoder->got_spspps)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        // CFDictionaryRef extensionDict = CMFormatDescriptionGetExtensions(format);
        // Get the extensions
        // From the extensions get the dictionary with key "SampleDescriptionExtensionAtoms"
        // From the dict, get the value for the key "avcC"
        
        size_t sps_size;
        const uint8_t *sps;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sps, &sps_size, NULL, NULL);
        if (statusCode == noErr)
        {
            // Found sps
            size_t pps_size;
            const uint8_t *pps;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pps, &pps_size, NULL, NULL);
            if (statusCode == noErr)
            {
                // Found pps
                if (encoder->_delegate)
                {
                    [encoder->_delegate H264HWEncoder_GotSpsPps:sps sps_length:sps_size pps:pps pps_length:pps_size pts_ms:(uint32_t)(pts.value * 1000 / encoder->_frame_rate)];
                    encoder->got_spspps = YES;
                }
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // Convert the length value from Big-endian to Little-endian
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);// 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
            [encoder->_delegate H264HWEncoder_GotEncodedData:dataPointer + bufferOffset + AVCCHeaderLength length:NALUnitLength pts_ms:(uint32_t)(pts.value * 1000 / encoder->_frame_rate) isKeyframe:keyframe];
            
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}

- (instancetype)initWithWidth: (int)width height: (int)height bit_rate:(unsigned long)bit_rate frame_rate:(int)fps
{
    if (self = [super init]) {
        queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        frameCount = 0;
        EncodingSession = nil;
        got_spspps = NO;
        
        // Create the compression session
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, output_callback, (__bridge void *)(self),  &EncodingSession);
        
        if (status != 0)
        {
            NSLog(@"Unable to create a H264 session!!!");
            return nil;
        }
        
        // 是否是实时的
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        
        // 设置允许编码器保留的最大帧数，设置为零即丢掉所有延迟帧，这样会导致在网络不好的情况下以极低的帧率推流，但是增加了实时性和程序的稳定性
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_MaxFrameDelayCount, (__bridge CFTypeRef)@(0));

        // ProfileLevel，h264的协议等级，不同的清晰度使用不同的ProfileLevel。
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
        
        // 设置码率，如果不设置，系统默认以极低的码率编码
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(bit_rate));
            //bps，平均码率，以bit为单位
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)@[@(bit_rate*2/8), @1]);
            //Bps，码率限制（不能超过），设置为bps的2倍，以byte为单位
        
        // 关闭重排Frame，因为有了B帧（双向预测帧，根据前后的图像计算出本帧）后，编码顺序可能跟显示顺序不同。此参数可以关闭B帧。
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        
        // 设置I帧间隔，即gop_size
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(fps*2));
        
        // 设置帧率，只用于初始化session，不是实际FPS
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(fps));
        
        // Tell the encoder to start encoding
        VTCompressionSessionPrepareToEncodeFrames(EncodingSession);
        
        self.frame_rate = fps;
    }
    return self;
}

- (void) encode:(CMSampleBufferRef )buffer
{
    dispatch_sync(queue, ^{
        
        frameCount++;
        // Get the CV Image buffer
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(buffer);
        
        // 时间戳，最后用CMSampleBufferGetPresentationTimeStamp得到的就是这个数值
        CMTime pts = CMTimeMake(frameCount, 1000);
        VTEncodeInfoFlags flags;
        
        // Pass it to the encoder
        OSStatus statusCode = VTCompressionSessionEncodeFrame(EncodingSession,
                                                              imageBuffer,
                                                              pts,
                                                              kCMTimeInvalid,
                                                              NULL, NULL, &flags);
        // Check for error
        if (statusCode != noErr) {
            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            
            // End the session
            VTCompressionSessionInvalidate(EncodingSession);
            CFRelease(EncodingSession);
            EncodingSession = NULL;
            return;
        }
//        NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
    });
}

- (void)dealloc
{
    NSLog(@"%s", __FUNCTION__);
    // Mark the completion
    VTCompressionSessionCompleteFrames(EncodingSession, kCMTimeInvalid);
    
    // End the session
    VTCompressionSessionInvalidate(EncodingSession);
    CFRelease(EncodingSession);
    EncodingSession = NULL;
}

@end
