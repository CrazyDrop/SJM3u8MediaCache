//
//  SJM3u8FileCache.m
//  SJVideoPlayer_Example
//
//  Created by apple on 2019/8/31.
//  Copyright © 2019年 changsanjiang. All rights reserved.
//

#import "SJM3u8FileCache.h"
#import <CommonCrypto/CommonHMAC.h>
#import <M3U8Kit/M3U8Kit.h>
#import <M3U8Kit/NSURL+m3u8.h>
#import "M3U8PlaylistModel+Update.h"
#import "M3U8SegmentInfo+Update.h"
#import "SJSubTSFileDownload.h"
#import <objc/message.h>
#import <AFNetworking/AFNetworking.h>

static NSString * BaseCacheDir = @"CacheM3u8";

//都需要追加文件名
static NSString * WebLocalM3u8 =  @"webOriginal.m3u8";
static NSString * WebPlayerM3u8 = @"webReplace.m3u8";
static NSString * CachedPlayerM3u8 = @"cacheReplace.m3u8";
static NSString * URLCacheLength = @"cacheLength";
@interface SJM3u8FileCache()
@property (nonatomic, strong) NSRecursiveLock * dataLock;
@property (nonatomic, strong) NSMutableDictionary * cacheDic;
@property (nonatomic, strong) NSMutableDictionary * resultDic;
@property (nonatomic, strong) NSMutableDictionary * workingDic;
@property (nonatomic, strong) AFHTTPSessionManager * manager;
@property (nonatomic, strong) NSOperationQueue * workQueue;
-(void)finishDownloadCacheWithWebURL:(NSURL *)webUrl;
-(void)checkListTsFileDownloadForNextStart;
@end

//代理处理回调  进行block调用
//绑定回调处理、下载对象
@interface  SJM3u8DownCacheTmpModel : NSObject<SJSubTSFileDownloadProgressDelegate>

@property (nonatomic, copy) SJWebVideoDownloaderProgressBlock progressBlock;
@property (nonatomic, copy) SJWebVideoDownloaderCompletedBlock completedBlock;
@property (nonatomic, strong) SJSubTSFileDownload * download;
@property (nonatomic, weak) SJM3u8FileCache * loadCache;

@end
@implementation SJM3u8DownCacheTmpModel

-(instancetype)initWithDownLoadModel:(SJSubTSFileDownload *)down{
    self = [super init];
    if(self){
        _download = down;
        down.delegate = self;
    }
    return self;
}

#pragma mark -- SJSubTSFileDownloadProgressDelegate
-(void)sjSubTSFileDownload:(SJSubTSFileDownload *)subModel finishDownloadSubURL:(NSString *)url  error:(NSError *)error{
    if(self.progressBlock){
        self.progressBlock(subModel.curIndex, subModel.totalNum, subModel.originalWebURL);
    }
}
-(void)sjSubTSFileDownload:(SJSubTSFileDownload *)subModel finishTotalDownloadWithFileList:(NSArray<NSString *> *)fileList andErrorArr:(NSArray<NSError *>  *)errList{
    if(self.completedBlock){
        BOOL totalFinish = YES;
        NSError * error = nil;
        if([errList count] > 0){
            error = [errList firstObject];
            totalFinish = NO;
        }
        NSURL * fileURL = [NSURL fileURLWithPath:subModel.combinePath];
        self.completedBlock(fileURL, error,totalFinish);
    }
    SJM3u8FileCache * fileCache = self.loadCache;
    [fileCache finishDownloadCacheWithWebURL:subModel.originalWebURL];
    [fileCache checkListTsFileDownloadForNextStart];
}
-(void)dealloc
{
    NSLog(@"%s",__FUNCTION__);
}
@end
@interface SJM3u8FileCache()
//@property (nonatomic, assign) BOOL isInRunning;
@end

@implementation SJM3u8FileCache


+(instancetype)sharedM3u8Cache
{
    static dispatch_once_t onceToken;
    static SJM3u8FileCache * _sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[SJM3u8FileCache alloc] init];
    });
    return _sharedInstance;
}
-(instancetype)init
{
    self = [super init];
    if(self){
        //默认缓存到tmp里,作为临时缓存数据
        NSString*docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject];
//        docDir = NSTemporaryDirectory();
        self.cachePath = [docDir stringByAppendingPathComponent:BaseCacheDir];
        self.dataLock = [[NSRecursiveLock alloc] init];
        self.cacheDic = @{}.mutableCopy;
        self.resultDic = @{}.mutableCopy;
        self.workingDic = @{}.mutableCopy;
        self.cacheSeconds = 10 * 60;//10分钟
        self.cacheSeconds = 1 * 60;//10分钟
        self.cacheNum = 3;  //同时缓存数量
        self.manager = [AFHTTPSessionManager manager];
        self.workQueue = [[NSOperationQueue alloc] init];
        [self checkDocumentCacheFileDirPathWithPath:self.cachePath];
        NSLog(@"%s cachePath %@",__FUNCTION__,self.cachePath);
    }
    return self;
}


#pragma mark -- PublicMethods
- (BOOL)isRunning{
    bool running = NO;
    [self.dataLock lock];
    running = [self.workingDic count] != 0 || [self.cacheDic count] != 0;
    [self.dataLock unlock];
    return running;
}


- (SJSubTSFileDownload *)cacheWebVideoWithURL:(nullable NSURL *)webUrl
                                     progress:(nullable SJWebVideoDownloaderProgressBlock)progressBlock
                                    completed:(nullable SJWebVideoDownloaderCompletedBlock)completedBlock
{
    if(![webUrl isM3u8PlayerUrl]){
        return nil;
    }
    
    __weak typeof(self) weakSelf = self;
    NSFileManager * cacheFileManager = [NSFileManager defaultManager];
    NSURL * readURL = webUrl;
    NSString * originalFilePath = [self cachedFileVideoWithWebUrl:webUrl fileName:WebLocalM3u8];
    NSString * webUrlFilePath = [self cachedFileVideoWithWebUrl:webUrl fileName:WebPlayerM3u8];
    if([cacheFileManager fileExistsAtPath:originalFilePath] && [cacheFileManager fileExistsAtPath:webUrlFilePath]){
        NSURL * fileUrl = [NSURL fileURLWithPath:originalFilePath isDirectory:NO];
        readURL = fileUrl;
    }else{
        [self checkDocumentCacheFileDirPathWithPath:[originalFilePath stringByDeletingLastPathComponent]];
    }
    
    //重复的缓存地址，不进行操作
    NSString * cacheKey = [[self class] keyForURL:webUrl];
    SJM3u8DownCacheTmpModel * temp = [self downloadCacheTmpForWebURLCacheKey:cacheKey];
    if(temp){
        return nil;
    }
    
    //本地存在、web请求
    SJSubTSFileDownload * resultDownload = [self createTSFileDownloadWithPlayListWebURL:webUrl];

    [readURL loadM3U8AsyncCompletion:^(M3U8PlaylistModel *model, NSError *error) {
        resultDownload.preDownFinish = YES;
        if(error)
        {
            resultDownload.preDownError = YES;
            [weakSelf.resultDic setObject:error forKey:cacheKey];
            return ;
        }
        //强制设定originalURL pod方法里不合适，进行强制设定
        [model setValue:webUrl forKey:@"originalURL"];
        if(![readURL isFileURL]){
            //主线程内 耗时操作，文件写入
            [weakSelf createM3u8CacheFileWithWebURL:webUrl andModel:model];
        }
        //添加任务到执行队列
        //任务真正执行，前面都是准备
        [weakSelf checkListTsFileDownloadForNextStart];
    }];
    
    [self addDownloadTmpForDataDownload:resultDownload
                               progress:progressBlock
                              completed:completedBlock];
    
    return resultDownload;
}
- (void)addDownloadTmpForDataDownload:(SJSubTSFileDownload *)download
                             progress:(nullable SJWebVideoDownloaderProgressBlock)progressBlock
                            completed:(nullable SJWebVideoDownloaderCompletedBlock)completedBlock
{
    [self.dataLock lock];
    
    NSURL * webURL = download.originalWebURL;
    NSString * cacheKey = [[self class] keyForURL:webURL];

    SJM3u8DownCacheTmpModel * temp = [[SJM3u8DownCacheTmpModel alloc] initWithDownLoadModel:download];
    temp.progressBlock = progressBlock;
    temp.completedBlock = completedBlock;
    temp.loadCache = self;
    
    [self.cacheDic setObject:temp forKey:cacheKey];
    [self.dataLock unlock];
}

- (SJM3u8DownCacheTmpModel *)downloadCacheTmpForWebURLCacheKey:(NSString *)cacheKey {
    SJM3u8DownCacheTmpModel *delegate = nil;
    [self.dataLock lock];
    delegate = [self.cacheDic objectForKey:cacheKey];
    if(!delegate){
        delegate = [self.workingDic objectForKey:cacheKey];
    }
    [self.dataLock unlock];
    return delegate;
}

//根据m3u8的url 缓存数据到文件，变更url
-(void)cacheWebUrlList:(NSArray *)urlList
{
    for (NSInteger index = 0;index < [urlList count] ;index ++ )
    {
        NSURL * webUrl = [urlList objectAtIndex:index];
        if(![webUrl isM3u8PlayerUrl]){
            continue;
        }
        //检查是否存在本地m3u8 存在的话，读取本地m3u8数据
        [self cacheWebVideoWithURL:webUrl
                          progress:nil
                         completed:nil];
    }
}

-(void)cancelM3u8CacheForWebUrl:(NSURL *)url{
    NSString * cacheKey =  [[self class] keyForURL:url];
    [self.dataLock lock];
    SJM3u8DownCacheTmpModel * downTemp = [self.workingDic objectForKey:cacheKey];
    [downTemp.download cancelCurrentTSFileDownload];
    [self.workingDic removeObjectForKey:cacheKey];
    [self.cacheDic removeObjectForKey:cacheKey];
    [self.dataLock unlock];
}

- (void)cancelAllCache{
    [self.dataLock lock];
    //清空未开启的任务队列
    NSArray * cacheList = [self.cacheDic allKeys];
    for (NSInteger index = 0;index <[cacheList count] ;index ++ )
    {
        NSString * eveKey = [cacheList objectAtIndex:index];
        SJM3u8DownCacheTmpModel * tempDown = [self.cacheDic objectForKey:eveKey];
        SJSubTSFileDownload * download = tempDown.download;
        if(!download.isInRequesting){
            [self.cacheDic removeObjectForKey:eveKey];
        }
    }
    
    //处理中的任务
    NSArray * workList = [self.workingDic allKeys];
    for (NSInteger index = 0;index <[workList count] ;index ++ )
    {
        NSString * eveKey = [workList objectAtIndex:index];
        SJM3u8DownCacheTmpModel * tempDown = [self.workingDic objectForKey:eveKey];
        SJSubTSFileDownload * download = tempDown.download;
        [download cancelCurrentTSFileDownload];
        [self.workingDic removeObjectForKey:eveKey];
    }
    [self.dataLock unlock];
}

-(void)removeM3u8CacheFilesForWebUrl:(NSURL *)webUrl{
    [self cancelM3u8CacheForWebUrl:webUrl];
    
    NSFileManager * manager = [NSFileManager defaultManager];
    NSString * filePath = [self cachedVideoPlayerFilePathForWebUrl:webUrl];
    NSString * dirPath = [filePath stringByDeletingLastPathComponent];
    
    NSError * error = nil;
    [manager removeItemAtPath:dirPath error:&error];
}


-(NSString *)cachedVideoPlayerFilePathForWebUrl:(NSURL *)webUrl
{
    NSString * filePath = [self cachedFileVideoWithWebUrl:webUrl fileName:CachedPlayerM3u8];
    return filePath;
}

-(BOOL)checkCacheVideoExsitWithWebUrl:(NSURL *)webUrl
{
    NSString * filePath = [self cachedVideoPlayerFilePathForWebUrl:webUrl];
    NSFileManager * manager = [NSFileManager defaultManager];
    BOOL exsit = [manager fileExistsAtPath:filePath];
    return exsit;
}

#pragma mark --
-(SJSubTSFileDownload *)createTSFileDownloadWithPlayListWebURL:(NSURL *)cacheUrl
{
//    NSURL * cacheUrl = model.originalURL;
    NSInteger cacheTime = [cacheUrl readCacheLength];
    if(cacheTime == -1){
        cacheTime = (NSUInteger)NSIntegerMax;
    }
    cacheUrl = [cacheUrl removeCacheLengthForM3u8];
    
    //缓存文本数据，修改web数据
    SJSubTSFileDownload * downModel = [[SJSubTSFileDownload alloc] init];
    downModel.cacheSecond = cacheTime > 0 ? cacheTime : self.cacheSeconds;
    downModel.originalWebURL = cacheUrl;
    downModel.replaceCachePath = [self cachedFileVideoWithWebUrl:cacheUrl fileName:WebPlayerM3u8];
    downModel.combinePath = [self cachedFileVideoWithWebUrl:cacheUrl fileName:CachedPlayerM3u8];
    downModel.manager = self.manager;
    
    return downModel;
}
// 检查文件是否存在
-(void)createM3u8CacheFileWithWebURL:(NSURL *)webURL andModel:(M3U8PlaylistModel *)model
{//进行文件创建
    NSString * originalFilePath = [self cachedFileVideoWithWebUrl:webURL fileName:WebLocalM3u8];
    NSString * webUrlFilePath = [self cachedFileVideoWithWebUrl:webURL fileName:WebPlayerM3u8];

    NSError * error = nil;
    NSURL * cacheUrl = model.originalURL;
    
    [model saveMediaPlaylist:model.mainMediaPl toFilePath:originalFilePath error:&error];
    
    NSString * sepListKey = @"mainMediaPl.segmentList.segmentInfoList";
    NSURL * rootURL = model.mainMediaPl.originalURL;
    if(!rootURL){
        rootURL = cacheUrl;
    }
    
    NSArray<M3U8SegmentInfo *> * readList = [model valueForKeyPath:sepListKey];
    [readList enumerateObjectsUsingBlock:^(M3U8SegmentInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.replaceURI = [NSURL URLWithString:obj.URI.absoluteString relativeToURL:rootURL];
    }];
    [model setValue:readList forKeyPath:sepListKey];
    [model saveMediaPlaylist:model.mainMediaPl toFilePath:webUrlFilePath error:&error];
}

-(void)checkListTsFileDownloadForNextStart
{
    [self.dataLock lock];
    NSInteger startNum = self.cacheNum - [self.workingDic count];
    while (startNum > 0) {
        NSArray * keyList = [self.cacheDic allKeys];
        if([keyList count] == 0){
            break;
        }
        NSString * eveKey = [keyList firstObject];
        SJM3u8DownCacheTmpModel * tempDown = [self.cacheDic objectForKey:eveKey];
        SJSubTSFileDownload * startObj = tempDown.download;
        if(startObj.preDownError)
        {//预处理失败，直接移除
            [self.cacheDic removeObjectForKey:eveKey];
        }
        
        if(startObj.preDownFinish == YES){
            [self.workingDic setObject:tempDown forKey:eveKey];
            [self.cacheDic removeObjectForKey:eveKey];
            
            //耗时操作，放到子线程里
            NSInvocationOperation * taskOperation = [[NSInvocationOperation alloc] initWithTarget:startObj selector:@selector(startTSFileDownloadAndCache) object:nil];
            [self.workQueue addOperation:taskOperation];
            startNum --;
        }
    }
    [self.dataLock unlock];
}
-(void)finishDownloadCacheWithWebURL:(NSURL *)webUrl
{//任务结束 ，移除obj
    NSString * cacheKey = [[self class] keyForURL:webUrl];
    [self.dataLock lock];
    SJM3u8DownCacheTmpModel * tempDown = [self.cacheDic objectForKey:cacheKey];
    SJSubTSFileDownload * startObj = tempDown.download;
    startObj.delegate = nil;
    [self.workingDic removeObjectForKey:cacheKey];
    [self.cacheDic removeObjectForKey:cacheKey];
    [self.dataLock unlock];
}

/*
-(void)cacheSubWebUrlList:(NSArray *)urlList
{
    NSLog(@"cacheSubWebUrlList [urlList count] %ld",[urlList count]);
    NSFileManager * manager = [NSFileManager defaultManager];
    for (NSInteger index = 0;index < [urlList count] ;index ++ )
    {
        NSURL * webUrl = [urlList objectAtIndex:index];
        
        //先判定缓存是否存在，然后进行后续操作
        NSString * originalFilePath = [self cachedFileVideoWithWebUrl:webUrl fileName:WebLocalM3u8];
        BOOL exsit = [manager fileExistsAtPath:originalFilePath];
        if(exsit)
        {//本地
            NSURL * fileUrl = [NSURL fileURLWithPath:originalFilePath];
            [self continueM3u8DetailRequestWithFilePath:fileUrl webURL:webUrl error:nil];
        }else{//异步
            [self checkDocumentCacheFileDirPathWithPath:[originalFilePath stringByDeletingLastPathComponent]];
            [self startWebM3u8FileUrlRequestWithWebUrlPath:webUrl filePath:originalFilePath];
        }
    }
    [self checkListTsFileDownloadForNextStart];
}


-(void)startWebM3u8FileUrlRequestWithWebUrlPath:(NSURL *)webUrl filePath:(NSString *)readFile
{
    NSURL * fileUrl = [NSURL fileURLWithPath:readFile];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:webUrl];
    NSURLSessionDownloadTask *downloadTask = [self.manager downloadTaskWithRequest:request progress:nil
                                                                       destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                                                                           return fileUrl;
                                                                           
                                                                       } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nonnull filePath, NSError * _Nonnull error)
                                              {
                                                  [self continueM3u8DetailRequestWithFilePath:filePath webURL:webUrl error:error];
                                                  [self checkListTsFileDownloadForNextStart];
                                              }];
    [downloadTask resume];
}

-(void)continueM3u8DetailRequestWithFilePath:(NSURL *)path webURL:(NSURL *)webUrl error:(NSError *)error
{
    NSError *readError = nil;
    M3U8PlaylistModel *listModel = nil;
    if(!error)
    {
        NSString * str = [NSString stringWithContentsOfURL:path encoding:NSUTF8StringEncoding error:&readError];
        
        listModel = [[M3U8PlaylistModel alloc] initWithString:str
                                                  originalURL:webUrl
                                                      baseURL:[webUrl URLByDeletingLastPathComponent]
                                                        error:&readError];
    }
    
    
    NSString * cacheKey = [[self class] keyForURL:webUrl];
    if(error || readError)
    {
        error = readError?readError:error;
        [self.resultDic setObject:error forKey:cacheKey];
        return ;
    }
    
    //强制设定originalURL pod方法里不合适，进行强制设定
    [listModel setValue:webUrl forKey:@"originalURL"];
    [self startSubTSFileDownloadWithPlaylistModel:listModel cacheKey:cacheKey];
}
 */

#pragma mark -- PrivateMethods
/**
 m3u8原始文件 包含服务器默认的本地ts路径文件
 m3u8缓存文件 包含服务器组合后的TS路径
 m3u8更新文件 供本地播放使用的文件 包含本地TS路径、服务器全地址TS路径
 **/
-(void)checkDocumentCacheFileDirPathWithPath:(NSString *)path
{
    NSURL * baseURL = [NSURL URLWithString:path];
    NSFileManager * manager = [NSFileManager defaultManager];
    NSString * tsFileDir = baseURL.absoluteString;
    
    NSError * error = nil;
    BOOL fileDir = NO;
    BOOL exsit = [manager fileExistsAtPath:tsFileDir isDirectory:&fileDir];
    if(!fileDir){
        //如果不是文件夹  移除
        [manager removeItemAtPath:tsFileDir error:&error];
        exsit = NO;
    }
    //创建ts文件夹
    if(!exsit){
        [manager createDirectoryAtPath:tsFileDir withIntermediateDirectories:YES attributes:nil error:&error];
    }
}
-(NSString *)cachedFileVideoWithWebUrl:(NSURL *)webUrl fileName:(NSString * )fileName
{
    NSString * cacheKey = [[self class] keyForURL:webUrl];
    NSString * filePath = [self.cachePath stringByAppendingPathComponent:cacheKey];
    filePath = [filePath stringByAppendingPathComponent:fileName];
    return filePath;
}

+ (NSString *)keyForURL:(NSURL *)url
{//key取值，移除缓存长度
    NSURL * readURL = [url removeCacheLengthForM3u8];
    NSString *urlString = [readURL absoluteString];
    if ([urlString length] == 0) {
        return nil;
    }
    
    // Strip trailing slashes so http://allseeing-i.com/ASIHTTPRequest/ is cached the same as http://allseeing-i.com/ASIHTTPRequest
    if ([urlString hasSuffix:@"/"]) {
        urlString = [urlString substringToIndex:[urlString length]-1];
    }
    
    const char *cStr = [urlString UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), result);
    return [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7],result[8], result[9], result[10], result[11],result[12], result[13], result[14], result[15]];
}

@end


@implementation NSURL (m3u8URLPragram)
- (BOOL)isM3u8PlayerUrl{
    NSString * baseExtend = [self pathExtension];
    NSString * m3u8Tag =  [baseExtend lowercaseString];
    if([m3u8Tag isEqualToString:@"m3u8"]){
        return YES;
    }
    return NO;
}

//添加长度
- (NSURL *)appendMaxedCacheForM3u8{
    NSURLComponents * coms = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:nil];
    NSArray<NSURLQueryItem *> * items = coms.queryItems;
    NSMutableArray * refreshItems = [NSMutableArray array];
    [refreshItems addObjectsFromArray:items];
    
    __block NSInteger replaceIndex = NSNotFound;
    [items enumerateObjectsUsingBlock:^(NSURLQueryItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString * queryName = obj.name;
        if([queryName isEqualToString:URLCacheLength]){
            replaceIndex = idx;
        }
    }];
    
    NSURLQueryItem * totalItem = [NSURLQueryItem queryItemWithName:URLCacheLength value:@"-1"];
    if(replaceIndex == NSNotFound){
        [refreshItems addObject:totalItem];
    }else{
        [refreshItems replaceObjectAtIndex:replaceIndex withObject:totalItem];
    }
    
    coms.queryItems = refreshItems;
    return coms.URL;
}

//移除长度
- (NSURL *)removeCacheLengthForM3u8{
    NSURLComponents * coms = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:nil];
    NSArray<NSURLQueryItem *> * items = coms.queryItems;
    NSMutableArray * refreshItems = [items mutableCopy];
    __block NSInteger replaceIndex = NSNotFound;
    [items enumerateObjectsUsingBlock:^(NSURLQueryItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString * queryName = obj.name;
        if([queryName isEqualToString:URLCacheLength]){
            replaceIndex = idx;
        }
    }];
    
    if(replaceIndex != NSNotFound){
        [refreshItems removeObjectAtIndex:replaceIndex];
    }
    
    if([refreshItems count] == 0){
        refreshItems = nil;
    }
    coms.queryItems = refreshItems;
    return coms.URL;
}

- (NSInteger)readCacheLength
{
    NSURLComponents * coms = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:nil];
    NSArray<NSURLQueryItem *> * items = coms.queryItems;
    __block NSInteger replaceIndex = NSNotFound;
    [items enumerateObjectsUsingBlock:^(NSURLQueryItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString * queryName = obj.name;
        if([queryName isEqualToString:URLCacheLength]){
            replaceIndex = idx;
            *stop = YES;
        }
    }];
    
    NSInteger cacheLength = 0;
    if(replaceIndex != NSNotFound){
        NSURLQueryItem * item = [items objectAtIndex:replaceIndex];
        cacheLength = [[item value] integerValue];
    }
    return cacheLength;
}

@end

@implementation UIView (SJM3u8FileCache)
//添加属性
- (void)setM3u8_SJCacheUrl:(NSURL *)url {
    NSURL * hisUrl = [self m3u8_SJCacheUrl];
    if([hisUrl isEqual:url]){
        return;
    }
    
    SJM3u8FileCache * fileCache = [SJM3u8FileCache sharedM3u8Cache];
    if(hisUrl){
        [fileCache cancelM3u8CacheForWebUrl:hisUrl];
    }
    if(url && [url isM3u8PlayerUrl]){
        [fileCache cacheWebUrlList:@[url]];
    }
    
    objc_setAssociatedObject(self, @selector(m3u8_SJCacheUrl), url, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
- (NSURL *)m3u8_SJCacheUrl {
    return objc_getAssociatedObject(self, _cmd);
}

@end

