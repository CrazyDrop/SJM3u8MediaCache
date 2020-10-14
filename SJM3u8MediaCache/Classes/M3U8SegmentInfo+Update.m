//
//  M3U8SegmentInfo+Update.m
//  SJM3u8MediaCache
//
//  Created by apple on 2019/8/31.
//  Copyright © 2019年 apple. All rights reserved.
//

#import "M3U8SegmentInfo+Update.h"
#import <objc/message.h>
@implementation M3U8SegmentInfo (Update)

//添加属性
- (void)setReplaceURI:(NSURL *)url {
    objc_setAssociatedObject(self, @selector(replaceURI), url, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
- (NSURL *)replaceURI {
    return objc_getAssociatedObject(self, _cmd);
}




@end
