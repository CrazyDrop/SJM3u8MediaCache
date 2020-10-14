//
//  M3U8SegmentInfo+Update.h
//  SJM3u8MediaCache
//
//  Created by apple on 2019/8/31.
//  Copyright © 2019年 apple. All rights reserved.
//

#import <M3U8Kit/M3U8Kit.h>

NS_ASSUME_NONNULL_BEGIN
//添加替换URL
@interface M3U8SegmentInfo (Update)

@property (nonatomic, copy) NSURL *replaceURI;

@end

NS_ASSUME_NONNULL_END
