//
//  M3U8PlaylistModel+Update.m
//  SJM3u8MediaCache
//
//  Created by apple on 2019/8/31.
//  Copyright © 2019年 apple. All rights reserved.
//

#import "M3U8PlaylistModel+Update.h"
#import "M3U8SegmentInfo+Update.h"
@implementation M3U8PlaylistModel (Update)

- (void)saveMediaPlaylist:(M3U8MediaPlaylist *)playlist toFilePath:(NSString *)path error:(NSError **)error {
    if (nil == playlist) {
        return;
    }
    NSString *mainMediaPlContext = [playlist.originalText copy];
    if (mainMediaPlContext.length == 0) {
        return;
    }
    
    //调整替换方法
    for (int i = 0; i < playlist.segmentList.count; i ++) {
        M3U8SegmentInfo *sinfo = [playlist.segmentList segmentInfoAtIndex:i];
        if(sinfo.replaceURI){
            mainMediaPlContext = [mainMediaPlContext stringByReplacingOccurrencesOfString:sinfo.URI.absoluteString withString:sinfo.replaceURI.absoluteString];
        }
    }
    
    NSString *mainMediaPlPath = path;
    NSString * extend = [path pathExtension];
    if([extend length] == 0){
        mainMediaPlPath = [path stringByAppendingPathComponent:playlist.name];
    }
    BOOL success = [mainMediaPlContext writeToFile:mainMediaPlPath atomically:YES encoding:NSUTF8StringEncoding error:error];
    if (NO == success) {
        if (NULL != error) {
            NSLog(@"M3U8Kit Error: failed to save mian media playlist to file. error: %@", *error);
        }
        return;
    }
}

@end
