//
//  SJM3u8FileCache.h
//  SJVideoPlayer_Example
//
//  Created by apple on 2019/8/31.
//  Copyright © 2019年 changsanjiang. All rights reserved.
//

#import <Foundation/Foundation.h>
@class SJSubTSFileDownload;
NS_ASSUME_NONNULL_BEGIN

//m3u8视频文件的部分缓存  缓存部分ts文件到本地，修改M3U8文件，进行混合路径的视频播放
/*
提供方法
 1、常用设置
 默认缓存根路径、最大并发缓存数量、默认缓存时长设定
2、开始缓存m3u8视频ts文件到本地
3、取消文件缓存
4、提供M3U8视频文件的播放地址、供本地服务器播放
5、判定是否存在缓存
6、取消缓存、并移除对应缓存文件

 NSURL扩展
 1、URL移除时长字段
 2、URL增加时长字段 缓存全部文件
 3、读取缓存时长
 
 UIView扩展
 m3u8_SJCacheUrl 视图对应缓存文件
 
*/

typedef void(^SJWebVideoDownloaderProgressBlock)(NSInteger receivedNum, NSInteger expectedFileNum, NSURL * _Nullable targetURL);
typedef void(^SJWebVideoDownloaderCompletedBlock)(NSURL * _Nullable localPath, NSError * _Nullable error, BOOL finished);


//进行m3u8视频资源的缓存，缓存后的播放，需要依赖httpserver
@interface SJM3u8FileCache : NSObject

//缓存工具单例
@property (nonatomic, class, readonly, nonnull) SJM3u8FileCache *sharedM3u8Cache;

/*
 缓存路径  默认路径为document
 */
@property (nonatomic, copy, nonnull) NSString * cachePath;

/*
 最大并发缓存数量 默认3
 */
@property (nonatomic, assign) NSInteger cacheNum;

/*
 默认缓存时长,单位为秒  默认1分钟
 */
@property (nonatomic, assign) NSTimeInterval cacheSeconds;


/**
 * 是否处于缓存中
 */
- (BOOL)isRunning;


/*
 单文件下载
 */
- (SJSubTSFileDownload *)cacheWebVideoWithURL:(nullable NSURL *)webUrl
                                     progress:(nullable SJWebVideoDownloaderProgressBlock)progressBlock
                                    completed:(nullable SJWebVideoDownloaderCompletedBlock)completedBlock;
/*
 根据m3u8的url 缓存数据到文件，变更url
 */
-(void)cacheWebUrlList:(NSArray *)urlList;


/*
 取消对应weburl的缓存操作
 */
-(void)cancelM3u8CacheForWebUrl:(NSURL *)url;

/**
 * 取消所有的缓存
 */
- (void)cancelAllCache;

/*
 取消当前缓存操作，移除对应缓存文件
 移除缓存数据  全部的缓存数据和部分缓存数据保持一致，使用部分的缓存数据进行key值标识
 */
-(void)removeM3u8CacheFilesForWebUrl:(NSURL *)url;


/*
 缓存webURL的本地m3u8视频路径，本地的缓存文件地址
 */
-(NSString *)cachedVideoPlayerFilePathForWebUrl:(NSURL *)webUrl;

/*
 检查weburl的缓存是否存在
 */
-(BOOL)checkCacheVideoExsitWithWebUrl:(NSURL *)webUrl;

@end

NS_ASSUME_NONNULL_END

@interface NSURL (m3u8URLPragram)
//拼接缓存长度到url内，如果存在缓存长度，则不使用默认缓存长度

- (BOOL)isM3u8PlayerUrl;

//添加长度,特定url，需要缓存全部数据时使用
- (NSURL *)appendMaxedCacheForM3u8;

//移除缓存时长长度
- (NSURL *)removeCacheLengthForM3u8;

//默认为0 -1时为缓存全部文件
- (NSInteger)readCacheLength;

@end


@interface UIView (SJM3u8FileCache)
/*
 给特定view添加缓存url，变更时，进行新url缓存、取消历史缓存操作
 */
@property (nonatomic, copy) NSURL *m3u8_SJCacheUrl;

@end
