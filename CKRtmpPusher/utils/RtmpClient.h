//
//  RtmpClient.h
//  CKRTSPClient
//
//  Created by sandy on 2017/1/4.
//  Copyright © 2017年 concox. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RtmpClient : NSObject

- (instancetype)init;

- (BOOL)write_h264_raw_frame: (uint8_t *)frame data_size: (int)frames_size pts:(uint32_t)pts dts: (uint32_t)dts;

/*
@param sound_format Format of SoundData. The following values are defined:
*               0 = Linear PCM, platform endian
*               1 = ADPCM
*               2 = MP3
*               3 = Linear PCM, little endian
*               4 = Nellymoser 16 kHz mono
*               5 = Nellymoser 8 kHz mono
*               6 = Nellymoser
*               7 = G.711 A-law logarithmic PCM
*               8 = G.711 mu-law logarithmic PCM
*               9 = reserved
*               10 = AAC
*               11 = Speex
*               14 = MP3 8 kHz
*               15 = Device-specific sound
*               Formats 7, 8, 14, and 15 are reserved.
*               AAC is supported in Flash Player 9,0,115,0 and higher.
*               Speex is supported in Flash Player 10 and higher.
* @param sound_rate Sampling rate. The following values are defined:
*               0 = 5.5 kHz
*               1 = 11 kHz
*               2 = 22 kHz
*               3 = 44 kHz
* @param sound_size Size of each audio sample. This parameter only pertains to
*               uncompressed formats. Compressed formats always decode
*               to 16 bits internally.
*               0 = 8-bit samples
*               1 = 16-bit samples
* @param sound_type Mono or stereo sound
*               0 = Mono sound
*               1 = Stereo sound */
- (BOOL)write_aac_raw_frame: (char *)frame data_size: (int)data_size
               sound_format: (char)sound_format sound_rate: (char)sound_rate
                 sound_size: (char)sound_size sound_type: (char)sound_type timestamp: (uint32_t)timestamp;

@end
