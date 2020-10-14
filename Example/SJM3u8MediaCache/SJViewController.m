//
//  SJViewController.m
//  SJM3u8MediaCache
//
//  Created by erik on 09/04/2019.
//  Copyright (c) 2019 erik. All rights reserved.
//

#import "SJViewController.h"
#import <SJM3u8MediaCache/SJM3u8MediaCache.h>
@interface SJViewController ()
@property (nonatomic, strong) UIButton *button;
@end

@implementation SJViewController

- (UIButton *)button
{
    if (!_button) {
        _button = [UIButton buttonWithType:UIButtonTypeCustom];
        _button.frame = CGRectMake(0, 100, 100, 100);
        [_button setTitle:@"测试" forState:UIControlStateNormal];
        [_button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [_button addTarget:self action:@selector(tapedOnTestButtonSender:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _button;
}

-(void)tapedOnTestButtonSender:(id)sender
{
    NSURL * webURL4 = [NSURL URLWithString:@"http://yun.kubo-zy-youku.com/20181112/BULbB7PC/index.m3u8"];
    webURL4 = [NSURL URLWithString:@"http://spcnd.kuangjianfu.com/detail/3197/vip/688d9255b45ec1e097d3ae4727411a95.m3u8"];
//    NSURL * replaceURL = [webUrl removeCacheLengthForM3u8];
    //默认只下载1分钟
    SJM3u8FileCache * cache = [SJM3u8FileCache sharedM3u8Cache];
//    [cache cacheWebVideoWithURL:webURL4 progress:nil completed:nil];
    [cache cacheWebVideoWithURL:webURL4
                       progress:^(NSInteger receivedPageNum, NSInteger expectedFileNum, NSURL * _Nullable targetURL) {
                           NSLog(@"%ld - %ld %@",receivedPageNum,expectedFileNum,targetURL);
                       }
                      completed:^(NSURL * _Nullable localPath, NSError * _Nullable error, BOOL finished) {
                           NSLog(@"result %d  error%@ localPath%@",finished,error,localPath);
                       }];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self.view addSubview:self.button];
    
    
    
//    NSURL * readURL = [NSURL URLWithString:@"http://cdn.cn2-letv.com/1001040/hls/index.m3u8?totalNum=10&next=124&cacheLength=copyURL"];
//    //    readURL = [readURL URLByDeletingLastPathComponent];
//    NSURL * nextURL = [NSURL URLWithString:@"next.png" relativeToURL:readURL];
    
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
