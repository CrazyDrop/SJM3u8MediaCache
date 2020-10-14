//
//  M3U8PlaylistModel+Update.h
//  SJM3u8MediaCache
//
//  Created by apple on 2019/8/31.
//  Copyright © 2019年 apple. All rights reserved.
//

#import <M3U8Kit/M3U8Kit.h>

NS_ASSUME_NONNULL_BEGIN
//pod方法不合适，进行调整修改的
@interface M3U8PlaylistModel (Update)

- (void)saveMediaPlaylist:(M3U8MediaPlaylist *)playlist toFilePath:(NSString *)path error:(NSError **)error;




@end

NS_ASSUME_NONNULL_END
