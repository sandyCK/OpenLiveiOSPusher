# CKRtmpPusher
iOS hardware encode and rtmp push

主要功能：

         1.在iOS设备上进行视音频采集，预览视频；

         2.视频使用VideoToolBox编码为h264，音频使用AudioToolBox编码为aac；
         
         3.编码后的数据使用srs-librtmp发送到服务器，可以用srs player（http://www.ossrs.net/players/srs_player.html）或者VLC观看；
         
注释：

         1.需要导入的库：VideoToolBox, AudioToolBox, AVFoundation
        
         2.编译设置：Apple LLVM 8.0 Language C++
                    
                    C++ Language Dialect ---------- GNU++98[-std=gnu++98]
                    
                    C++ Standard Library ---------- libstdc++(GNU C++ standard library)
