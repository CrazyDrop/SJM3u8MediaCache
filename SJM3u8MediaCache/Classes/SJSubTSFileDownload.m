//
//  SJSubTSFileDownload.m
//  SJVideoPlayer_Example
//
//  Created by apple on 2019/8/31.
//  Copyright © 2019年 changsanjiang. All rights reserved.
//

#import "SJSubTSFileDownload.h"
#import <M3U8Kit/M3U8Kit.h>
#import <M3U8Kit/NSURL+m3u8.h>
#import <M3U8Kit/M3U8PlaylistModel.h>
#import "M3U8PlaylistModel+Update.h"
#import "M3U8SegmentInfo+Update.h"
#import <AFNetworking/AFNetworking.h>
static NSString * const SJLocalSubPath = @"TSFiles";

@interface SJSubTSFileDownload()
{
    NSTimeInterval cacheTime;
}
@property (nonatomic, strong) M3U8PlaylistModel * mainInfo;

//为了方便多并发，可以使用字典形式
@property (nonatomic, strong) NSArray<M3U8SegmentInfo *> * tsList;
@property (nonatomic, strong) NSMutableDictionary * workingDic;

@end

@implementation SJSubTSFileDownload

-(id)init
{
    self = [super init];
    if(self){
        self.workingDic = [NSMutableDictionary dictionary];
        NSLog(@"%s ",__FUNCTION__);
    }
    return self;
}

//一组请求的预处理  生成数组等参数 请求开启后无效  对文件预处理
-(void)prepareListTSRequest{
    //读取文件  写入本地文件  文件数据检查、检索出需要更新的数据
    NSArray<M3U8SegmentInfo *>  * total = nil;
    NSArray<M3U8SegmentInfo *>  * comTotal = nil;
    NSString * sepListKey = @"mainMediaPl.segmentList.segmentInfoList";
    
    //先选中mainInfo 再设定total、comTotal
    NSError *error = nil;
    NSString * str = [NSString stringWithContentsOfFile:self.replaceCachePath encoding:NSUTF8StringEncoding error:&error];
    
    M3U8PlaylistModel *listModel = [[M3U8PlaylistModel alloc] initWithString:str
                                                                 originalURL:self.originalWebURL baseURL:[self.originalWebURL URLByDeletingLastPathComponent]
                                                                       error:&error];
    NSAssert(listModel != nil, @"本地m3u8文件肯定存在");
    

    NSString * comStr = [NSString stringWithContentsOfFile:self.combinePath encoding:NSUTF8StringEncoding error:&error];
    
    //先进行填充写入
    if([comStr length] == 0 || error){
        //生成最早的合并数据，存在历史数据，不进行创建
        self.mainInfo = listModel;
        [listModel saveMediaPlaylist:listModel.mainMediaPl toFilePath:self.combinePath error:&error];
    }else{
        
        M3U8PlaylistModel *comModel = [[M3U8PlaylistModel alloc] initWithString:comStr
                                                                    originalURL:self.originalWebURL baseURL:[self.originalWebURL URLByDeletingLastPathComponent]
                                                                          error:&error];
        
        self.mainInfo = comModel;
        comTotal = [listModel valueForKeyPath:sepListKey];
    }
    
    total = [self.mainInfo valueForKeyPath:sepListKey];

    //创建ts文件夹
    NSURL * baseURL = [[NSURL URLWithString:self.combinePath] URLByDeletingLastPathComponent];
    NSURL * tsDirURL = [baseURL URLByAppendingPathComponent:SJLocalSubPath];
    NSFileManager * manager = [NSFileManager defaultManager];
    NSString * tsFileDir = tsDirURL.absoluteString;
    
    BOOL fileDir = NO;
    BOOL exsit = [manager fileExistsAtPath:tsFileDir isDirectory:&fileDir];
    if(!fileDir){//如果不是文件夹  移除
        [manager removeItemAtPath:tsFileDir error:&error];
        exsit = NO;
    }
    if(!exsit){
        [manager createDirectoryAtPath:tsFileDir withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    
    NSMutableArray * requestArr = [NSMutableArray array];
    __block NSTimeInterval countTime = 0;
    __weak typeof(self) Weakself = self;
    [total enumerateObjectsUsingBlock:^(M3U8SegmentInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        M3U8SegmentInfo * combineInfo = [comTotal count] > idx ? [comTotal objectAtIndex:idx]: nil;
        countTime += obj.duration;
        if(!combineInfo || [combineInfo.URI isEqual:obj.URI]){
            [requestArr addObject:obj];
        }
        if(countTime > Weakself.cacheSecond){
            *stop = YES;
        }
    }];
    
    _curIndex = 0;
    _tsList = requestArr;
    _totalNum = [requestArr count];
}

//ts下载结束回调
-(void)refreshCacheListWithWebURL:(NSString *)url andResultError:(NSError *)error
{
    BOOL success = error == nil;
    _curIndex ++;
    
    //每个任务执行完成
    if(self.delegate && [self.delegate respondsToSelector:@selector(sjSubTSFileDownload:finishDownloadSubURL:error:)]){
        [self.delegate sjSubTSFileDownload:self finishDownloadSubURL:url error:error];
    }
    
    M3U8SegmentInfo * info = [self.workingDic objectForKey:url];
    NSString * part = [self localTSFilePartPathForUrl:url];
    if(success){
        info.replaceURI = [NSURL URLWithString:part];
        [self.mainInfo saveMediaPlaylist:self.mainInfo.mainMediaPl toFilePath:self.combinePath error:nil];
    }
    
    //失败不进行替换、成功进行部分替换
    [self.workingDic removeObjectForKey:url];
    
    [self realTSFileRequestWithLatestCacheList];
}


//开始下载  至少开启一个下载  进行一组循环请求，每次一个文件  控制多并发问题
-(void)startTSFileDownloadAndCache{
    if(self.isInRequesting) return;
    self.isInRequesting = YES;
    
    [self prepareListTSRequest];
    
    [self realTSFileRequestWithLatestCacheList];
}

-(void)realTSFileRequestWithLatestCacheList
{
    if([self.tsList count] > self.curIndex){
        M3U8SegmentInfo * info = [self.tsList objectAtIndex:self.curIndex];
        
        NSString * tsUrl = info.URI.absoluteString;
        [self.workingDic setObject:info forKey:tsUrl];
        [self startTSFileRequestWithWebUrl:tsUrl];
    }else{
        //全部任务执行结束
        if(self.delegate && [self.delegate respondsToSelector:@selector(sjSubTSFileDownload:finishTotalDownloadWithFileList:andErrorArr:)]){
            [self.delegate sjSubTSFileDownload:self finishTotalDownloadWithFileList:nil andErrorArr:nil];
        }
        self.isInRequesting = NO;
    }
}
-(NSString *)localTSFilePartPathForUrl:(NSString *)webUrl
{
    NSString * tsPartPath = [SJLocalSubPath stringByAppendingPathComponent:webUrl.lastPathComponent];
    return tsPartPath;
}

-(void)startTSFileRequestWithWebUrl:(NSString *)webUrl
{
    NSString * part = [self localTSFilePartPathForUrl:webUrl];
    NSURL * rootUrl = [[NSURL URLWithString:self.combinePath] URLByDeletingLastPathComponent];
    rootUrl = [rootUrl URLByAppendingPathComponent:part];
    
    NSURL * fileUrl = [NSURL fileURLWithPath:[rootUrl absoluteString]];
    //判定文件内是否存在  已经存在，放弃请求，
    NSFileManager * manager = [NSFileManager defaultManager];
    if([manager fileExistsAtPath:rootUrl.absoluteString])
    {
        [self refreshCacheListWithWebURL:webUrl andResultError:nil];
        return;
    }
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString: webUrl]];
    NSURLSessionDownloadTask *downloadTask = [self.manager downloadTaskWithRequest:request progress:nil
                                                                       destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        return fileUrl;
        
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nonnull filePath, NSError * _Nonnull error) {
        
        [self refreshCacheListWithWebURL:webUrl andResultError:error];
    }];
    
    //3.启动任务
    [downloadTask resume];
}


//取消下载
-(void)cancelCurrentTSFileDownload{
    self.tsList = nil;
    [self realTSFileRequestWithLatestCacheList];
}

-(void)dealloc
{
    NSLog(@"%s %@",__FUNCTION__,self.originalWebURL);
}

@end
