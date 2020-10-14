//
//  SJSubTSFileDownload.h
//  SJVideoPlayer_Example
//
//  Created by apple on 2019/8/31.
//  Copyright © 2019年 changsanjiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>

NS_ASSUME_NONNULL_BEGIN
//封装ts文件的下载、完成文件下载、存储  下载结果回调
//接收request参数 封装一组ts文件下载，使用同一个session，方便取消
//内部使用afn进行数据请求  进行文件下载 m3u8文件修改
//
@class SJSubTSFileDownload;
@protocol SJSubTSFileDownloadProgressDelegate <NSObject>

@optional

-(void)sjSubTSFileDownload:(SJSubTSFileDownload *)subModel finishDownloadSubURL:(NSString *)url  error:(NSError *)error;
/*
 成功的文件列表
 失败的数组  失败数据内包含url 失败原因
 */
-(void)sjSubTSFileDownload:(SJSubTSFileDownload *)subModel finishTotalDownloadWithFileList:(NSArray<NSString *> *)fileList andErrorArr:(NSArray<NSError *>  *)errList;
@end

@interface SJSubTSFileDownload : NSObject

//提前下载结束
@property (nonatomic, assign) BOOL preDownFinish;
@property (nonatomic, assign) BOOL preDownError;

//缓存的时长  s为单位
@property (nonatomic, assign) NSUInteger cacheSecond;

//m3u8服务器端下载路径
@property (nonatomic, strong) NSURL  *originalWebURL;

//m3u8内 短路径为本地地址  https为web地址，需要针对web进行下载
//原始m3u8 内含短路径替换web路径的文件地址
@property (nonatomic, strong) NSString  *replaceCachePath;

//修改的m3u8 使用本地文件路径替换web路径 TSFiles
@property (nonatomic, strong) NSString  *combinePath;

//是否处于请求中
@property (nonatomic, assign) NSInteger isInRequesting;

//
@property (nonatomic, strong) AFHTTPSessionManager * manager;

//当前id
@property (nonatomic, assign, readonly) NSInteger curIndex;

//预计数量
@property (nonatomic, assign, readonly) NSInteger totalNum;

//回调代理
@property (nonatomic, weak) id<SJSubTSFileDownloadProgressDelegate> delegate;

//一组请求的预处理  生成数组等参数 请求开启后无效  对文件预处理
-(void)prepareListTSRequest;

//开始下载  至少开启一个下载  进行一组循环请求，每次一个文件  控制多并发问题
-(void)startTSFileDownloadAndCache;

//取消下载
-(void)cancelCurrentTSFileDownload;

//结果回调bloc
@property (nonatomic, copy) void(^SubTJDownloadFinishBlock)(NSArray<NSString *> * fileList, NSArray<NSError *> * errList);

@end

NS_ASSUME_NONNULL_END
