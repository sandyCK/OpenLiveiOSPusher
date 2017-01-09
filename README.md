# OpenLiveiOSPusher
本项目使用到了开源的srs-librtmp（https://github.com/ossrs/srs-librtmp）

我们的开源项目汇总：https://github.com/devillee/OpenLive

主要功能：

         1.在iOS设备上进行视音频采集，预览视频；

         2.视频使用VideoToolBox编码为h264，音频使用AudioToolBox编码为aac；
         
         3.编码后的数据使用srs-librtmp发送到服务器，可以用srs player（http://www.ossrs.net/players/srs_player.html）或者VLC观看；
         
注释：

         1.需要导入的库：VideoToolBox, AudioToolBox, AVFoundation
        
         2.编译设置：Apple LLVM 8.0 Language C++
                    
                    C++ Language Dialect ---------- GNU++98[-std=gnu++98]
                    
                    C++ Standard Library ---------- libstdc++(GNU C++ standard library)

提供一种关于视频朝向的解决方法：

         系统默认的采集视频的方向为LandscapeLeft（左边横屏，Home键向右），并且只有宽大于高的分辨率选择，假如你想输出竖屏的视频，可以在LiveViewController中，initCamera方法中设置帧率后面加上[[self.videoOutput connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:AVCaptureVideoOrientationPortrait]，这时采集视频的方向是竖屏，但是分辨率仍然是640*480的横屏分辨率。然后，初始化h264编码器时直接将宽高设置为你想要的竖屏分辨率，比如480*640，编码器自己会对原始图像做resize。设置完这两个地方，你就会发现输出的视频分辨率是480*640，并且采集的方向是Portrait。
