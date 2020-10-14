//
//  SJM3u8MediaCacheTests.m
//  SJM3u8MediaCacheTests
//
//  Created by erik on 09/04/2019.
//  Copyright (c) 2019 erik. All rights reserved.
//

@import XCTest;
@import SJM3u8MediaCache;
@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}
-(void)tapedOnWebURLUpdate:(id)sender
{
    NSURL * mp4URL = [NSURL URLWithString:@"https://bitmovin-a.akamaihd.net/content/playhouse-vr/m3u8s/105560_video_720_3000000.mp4?aab=2332&ddd=222"];
    NSURL * m3u8URL = [NSURL URLWithString:@"https://bitmovin-a.akamaihd.net/content/playhouse-vr/m3u8s/105560_video_720_3000000.m3u8?aab=2332&ddd=222"];
    XCTAssert(![mp4URL isM3u8PlayerUrl],@"判定mp4链接不是m3u8链接");
    XCTAssert([m3u8URL isM3u8PlayerUrl],@"判定m3u8链接是m3u8链接");
    
    //URL长度计算
    NSURL * webURL2 = [NSURL URLWithString:@"https://bitmovin-a.akamaihd.net/content/playhouse-vr/m3u8s/105560_video_720_3000000.m3u8?aab=2332&ddd=222"];
    NSURL * updateURL = [webURL2 appendMaxedCacheForM3u8];
    XCTAssert([[updateURL absoluteString] containsString:@"cacheLength"],@"时间key值为cacheLength");
    
    NSTimeInterval timeNum = [updateURL readCacheLength];
    XCTAssert(timeNum == -1,@"默认全部下载时间长度为-1");
    
    NSURL * baseURL = [updateURL removeCacheLengthForM3u8];
    NSTimeInterval baseNum = [baseURL readCacheLength];
    XCTAssert(baseNum == 0,@"移除长度后 长度为0");
    XCTAssert(![[baseURL absoluteString] containsString:@"cacheLength"],@"移除后cacheLength的参数不存在");
}


-(void)testDownloadVideoList{
    NSURL * webUrl = [NSURL URLWithString:@"http://youku.com-www-163.com/20180506/576_bf997390/index.m3u8"];
    
    NSURL * webURL1 = [NSURL URLWithString:@"https://www3.yuboyun.com/hls/2018/11/25/SmRqndpr/playlist.m3u8"];
    NSURL * webURL2 = [NSURL URLWithString:@"https://bitmovin-a.akamaihd.net/content/playhouse-vr/m3u8s/105560_video_720_3000000.m3u8"];
    NSURL * webURL3 = [NSURL URLWithString:@"http://asp.cntv.myalicdn.com/asp/hls/1200/0303000a/3/default/4f4c61936bec8164557673a34fe21123/1200.m3u8"];
    NSURL * webURL4 = [NSURL URLWithString:@"http://yun.kubo-zy-youku.com/20181112/BULbB7PC/index.m3u8"];
    
    //默认只下载1分钟
    SJM3u8FileCache * cache = [SJM3u8FileCache sharedM3u8Cache];
    [cache cacheWebUrlList:@[webUrl,webURL1,webURL2,webURL3,webURL4]];
}
-(void)testDownloadTotalVideoList{
    NSURL * webUrl = [NSURL URLWithString:@"http://youku.com-www-163.com/20180506/576_bf997390/index.m3u8"];
    webUrl = [webUrl appendMaxedCacheForM3u8];

    //下载全部文件
    SJM3u8FileCache * cache = [SJM3u8FileCache sharedM3u8Cache];
    [cache cacheWebUrlList:@[webUrl]];
}
-(void)testDownloadVideoProgress{
    NSURL * webUrl = [NSURL URLWithString:@"https://www3.yuboyun.com/hls/2018/11/25/SmRqndpr/playlist.m3u8"];
    
    //下载全部文件
    SJM3u8FileCache * cache = [SJM3u8FileCache sharedM3u8Cache];
    [cache cacheWebVideoWithURL:webUrl
                       progress:^(NSInteger receivedPageNum, NSInteger expectedFileNum, NSURL * _Nullable targetURL) {
                           NSLog(@"%ld - %ld %@",receivedPageNum,expectedFileNum,targetURL);
                       }
                      completed:^(NSURL * _Nullable localPath, NSError * _Nullable error, BOOL finished) {
                          NSLog(@"result %d  error%@ localPath%@",finished,error,localPath);
                       }];
}

- (void)testExample
{
    XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

@end

