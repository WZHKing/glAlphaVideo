//
//  ViewController.m
//  glAlphaVideo
//
//  Created by wzh on 2019/11/4.
//  Copyright © 2019 wzh. All rights reserved.
//

#import "ViewController.h"
#import "NextViewController.h"

@interface GiftModel : NSObject
@property(nonatomic, copy) NSString *desTitle;
@property(nonatomic, copy) NSString *resName;
@end
@implementation GiftModel
@end

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) NSArray *dataArray;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    GiftModel *m1 = [[GiftModel alloc] init];
    m1.desTitle = @"跑车动画";
    m1.resName = @"giftcar";
    GiftModel *m2 = [[GiftModel alloc] init];
    m2.desTitle = @"K宝动画";
    m2.resName = @"giftKB";
    
    
    _dataArray = @[m1, m2];
    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
}

#pragma mark - UITableViewDelegate, UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _dataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"identifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    GiftModel *m = _dataArray[indexPath.row];
    cell.textLabel.text = m.desTitle;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NextViewController *vc = [[NextViewController alloc] init];
    GiftModel *m = _dataArray[indexPath.row];
    NSString *urlPath = [[NSBundle mainBundle] pathForResource:m.resName ofType:@"mp4"];
    NSURL *videoUrl = [NSURL fileURLWithPath:urlPath];
    vc.videoURL = videoUrl;
    [self.navigationController pushViewController:vc animated:true];
}

@end
