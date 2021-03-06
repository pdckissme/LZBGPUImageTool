//
//  ViewController.m
//  LZBGPUImageTool
//
//  Created by zibin on 2017/4/20.
//  Copyright © 2017年 Apple. All rights reserved.
//  简书主页：http://www.jianshu.com/u/268ed1ef819e
//  共享demo资料QQ群：490658347
//  git地址：https://github.com/lzbgithubcode/LZBGPUImageTool

#import "ViewController.h"
#import "LZBCircleProcessView.h"
#import "LZBFilterCollectionViewCell.h"
#import "LZBFilterHandleTool.h"
#import "LZBAdjustTableViewCell.h"
#import "LZBAdjustView.h"
#import "LZBPlayerViewController.h"


#define LZBImageViewWidth  720
#define LZBImageViewHeight  1280
#define collectionViewHeight  80

#define filterButton_WithHeight 40

static NSString *LZBFilterCollectionViewCellID = @"LZBFilterCollectionViewCellID";

@interface ViewController ()<UICollectionViewDataSource,UICollectionViewDelegate>

//媒体属性
@property (nonatomic, strong) NSString *videoPath;
@property (nonatomic, strong) NSMutableDictionary *videoSettings;


//相机
@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) GPUImageFilterGroup *filterGroup;
@property (nonatomic, strong) GPUImageView *videoImageView;
@property (nonatomic, strong) GPUImageMovieWriter *videoWriter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *currentFilter;

//UI
@property (nonatomic, strong) UIButton *filterButton;
@property (nonatomic, strong) UIButton *adjustButton;
@property (nonatomic, strong) LZBCircleProcessView *circleView;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray <LZBAdjustTableViewCellModel *> *adjustModels;


//data
@property (nonatomic, strong) NSMutableArray *filterModels;
@property (nonatomic, assign) BOOL isShowFilterView;

@end

@implementation ViewController
- (void)loadView
{
    [super loadView];
    [self initFilterData];
    self.isShowFilterView = NO;
}


- (void)viewDidLoad {
    [super viewDidLoad];
   
    
    [self.view insertSubview:self.videoImageView atIndex:0];
    [self.view addSubview:self.filterButton];
    [self.view addSubview:self.circleView];
    [self.view addSubview:self.collectionView];
    [self.view addSubview:self.adjustButton];
    [self createNewWritterWithisStart:YES];
    [self addGestureWithCamera];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.videoCamera startCameraCapture];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    CGFloat  defaultMargin = self.view.bounds.size.width * 0.1;
    self.videoImageView.frame = self.view.bounds;
    self.filterButton.frame = CGRectMake(defaultMargin, self.view.bounds.size.height - 60,filterButton_WithHeight, filterButton_WithHeight);
    self.adjustButton.frame = CGRectMake(self.view.bounds.size.width -defaultMargin-filterButton_WithHeight , self.filterButton.frame.origin.y, filterButton_WithHeight, filterButton_WithHeight);
    self.circleView.bounds = CGRectMake(0, 0, 80, 80);
    self.circleView.center = CGPointMake(self.view.frame.size.width*0.5, self.view.frame.size.height -40-30);
}

#pragma mark - Event
//滤镜按钮点击
- (void)filterButtonAction:(UIButton *)filterButton
{
    [LZBAdjustView dismissAdjustView];
    
    filterButton.selected = !filterButton.isSelected;
    if(filterButton.selected)
    {
        [self showFilterChooseView];
    }
    else
    {
        [self hiddenFilterChooseView];
    }
}

- (void)adjustButtonAction:(UIButton *)adjustButton
{
    [self hiddenFilterChooseView];
    //调节按钮点击
    [LZBAdjustView showWithModels:self.adjustModels didSlideBlock:^(LZBAdjustTableViewCellModel *model) {
        switch (model.adjustType) {
            case LZBAdjustType_None:
                return;
                break;
            case LZBAdjustType_Brightness:
            {
                GPUImageBrightnessFilter *brightnessFilter = [[GPUImageBrightnessFilter alloc]init];
                brightnessFilter.brightness = model.value;
                [self changeFilter:brightnessFilter];
            }
                break;
            case LZBAdjustType_Exposures:
            {
                GPUImageExposureFilter *exposureFilter = [[GPUImageExposureFilter alloc]init];
                exposureFilter.exposure = model.value;
                [self changeFilter:exposureFilter];
            }
                break;
            case LZBAdjustType_Contrast:
            {
                GPUImageContrastFilter *contrastFilter = [[GPUImageContrastFilter alloc]init];
                contrastFilter.contrast = model.value;
                [self changeFilter:contrastFilter];
            }
                break;
            case LZBAdjustType_Saturation:
            {
                GPUImageSaturationFilter *saturationFilter = [[GPUImageSaturationFilter alloc]init];
                saturationFilter.saturation = model.value;
                [self changeFilter:saturationFilter];
            }
                break;
            case LZBAdjustType_Gamma:
            {
                GPUImageGammaFilter *gammaFilter = [[GPUImageGammaFilter alloc]init];
                gammaFilter.gamma = model.value;
                [self changeFilter:gammaFilter];
            }
                break;
                
            default:
                break;
        }
    }];
}

//拍视频按钮点击
- (void)circleViewLongTouch:(UILongPressGestureRecognizer *)longGesture
{
    if(longGesture.state == UIGestureRecognizerStateBegan)
    {
        [self.circleView startAnimation];
        [self beginRecord];
    }
    else if (longGesture.state == UIGestureRecognizerStateEnded)
    {
        [self endRecord];
        [self.circleView stopAnimation];
    }
}

#pragma mark - handel
- (void)beginRecord
{
    unlink([self.videoPath UTF8String]);
    if(self.currentFilter != nil)
    [self.currentFilter addTarget:self.videoWriter];
   
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.videoCamera.audioEncodingTarget = self.videoWriter;
        [self.videoWriter startRecording];
    });
}

- (void)endRecord
{
    if(self.currentFilter != nil)
        [self.currentFilter removeTarget:self.videoWriter];
    
    [self.circleView stopAnimation];
    __weak typeof(self) weakSelf = self;
    // 储存到图片库,并且设置回调.
    [self.videoWriter finishRecordingWithCompletionHandler:^{
        [weakSelf createNewWritterWithisStart:NO];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf gotoPlayer];
        });
    }];
}


- (void)gotoPlayer
{
    LZBPlayerViewController *player = [[LZBPlayerViewController alloc]init];
    player.videoPath = self.videoPath;
    player.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:player animated:NO completion:nil];
}

- (void)createNewWritterWithisStart:(BOOL)isCameraCapture {
    
    [self.videoCamera removeTarget:self.videoWriter];
    
    self.videoWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:[NSURL fileURLWithPath:self.videoPath] size:CGSizeMake(LZBImageViewWidth , LZBImageViewWidth) fileType:AVFileTypeMPEG4 outputSettings:self.videoSettings];
    if(isCameraCapture)
    {
        [self.videoCamera addAudioInputsAndOutputs];
        self.videoCamera.audioEncodingTarget = self.videoWriter;
        [self.videoCamera startCameraCapture];
        self.currentFilter =[[GPUImageFilter alloc] init]; //默认
        [self changeFilter:self.currentFilter];
    }
    
}

- (void)addGestureWithCamera
{
    UISwipeGestureRecognizer *swipeGestureLeft= [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(handelSwipeGesture:)];
    swipeGestureLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:swipeGestureLeft];
    
    UISwipeGestureRecognizer *swipeGestureRight= [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(handelSwipeGesture:)];
    swipeGestureRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeGestureRight];
    
    UISwipeGestureRecognizer *swipeGestureup= [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(handelSwipeGesture:)];
    swipeGestureup.direction = UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:swipeGestureup];
    
    UISwipeGestureRecognizer *swipeGestureDown= [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(handelSwipeGesture:)];
    swipeGestureDown.direction = UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:swipeGestureDown];
}
- (void)handelSwipeGesture:(UISwipeGestureRecognizer *)swipeGesture
{
    switch (swipeGesture.direction) {
        case UISwipeGestureRecognizerDirectionLeft:
            [self showFilterChooseView];
            break;
        case UISwipeGestureRecognizerDirectionRight:
            [self hiddenFilterChooseView];
            break;
        case UISwipeGestureRecognizerDirectionUp:
            
            break;
        case UISwipeGestureRecognizerDirectionDown:
            
            break;            
        default:
            break;
    }
}

//显示滤镜选择View
- (void)showFilterChooseView
{
    if(self.isShowFilterView) return;
    self.collectionView.frame = CGRectMake([UIScreen mainScreen].bounds.size.width, 20, [UIScreen mainScreen].bounds.size.width, collectionViewHeight);
    [UIView animateWithDuration:0.25 animations:^{
        self.collectionView.frame = CGRectMake(0,20, [UIScreen mainScreen].bounds.size.width, collectionViewHeight);
    } completion:^(BOOL finished) {
         self.isShowFilterView = YES;
    }];
}

//隐藏滤镜选择View
- (void)hiddenFilterChooseView
{
      if(!self.isShowFilterView) return;
    self.collectionView.frame = CGRectMake(0, 20, [UIScreen mainScreen].bounds.size.width, collectionViewHeight);
    [UIView animateWithDuration:0.25 animations:^{
        self.collectionView.frame = CGRectMake([UIScreen mainScreen].bounds.size.width, 20, [UIScreen mainScreen].bounds.size.width, collectionViewHeight);
    } completion:^(BOOL finished) {
        self.isShowFilterView = NO;
    }];
}

#pragma mark - collection
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.filterModels.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    LZBFilterCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:LZBFilterCollectionViewCellID forIndexPath:indexPath];
    cell.filterModel = self.filterModels[indexPath.row];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake([LZBFilterCollectionViewCell getFilterCollectionViewCellHeight], [LZBFilterCollectionViewCell getFilterCollectionViewCellHeight]);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.row >=self.filterModels.count) return;
    GPUImageOutput<GPUImageInput> *filter = [[LZBFilterHandleTool sharedInstance] getFilterWithfilterType:indexPath.row];
    [self changeFilter:filter];
}


- (void)changeFilter:(GPUImageOutput<GPUImageInput>*)filter
{
    if(filter == nil)
    {
        [self.videoCamera removeAllTargets];
        [self.videoCamera addTarget:self.videoImageView];
        return;
    }
    [self.videoCamera removeAllTargets];
    [self.videoCamera addTarget:filter];
    [filter addTarget:self.videoImageView];
    [self.videoCamera startCameraCapture];
    self.currentFilter = filter;
}

- (void)addAdjustFilter:(GPUImageOutput<GPUImageInput>*)filter
{
    if(filter == nil) return;

}

#pragma mark- lazy
- (GPUImageVideoCamera *)videoCamera
{
  if(_videoCamera == nil)
  {
      // 创建视频源
      // SessionPreset:屏幕分辨率，AVCaptureSessionPresetHigh会自适应高分辨率
      // cameraPosition:摄像头方向
      _videoCamera = [[GPUImageVideoCamera alloc]initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionBack];
      _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
      _videoCamera.horizontallyMirrorFrontFacingCamera = YES;
  }
    return _videoCamera;
}

- (GPUImageFilterGroup *)filterGroup
{
  if(_filterGroup == nil)
  {
      _filterGroup = [[GPUImageFilterGroup alloc]init];
  }
    return _filterGroup;
}
- (GPUImageView *)videoImageView
{
  if(_videoImageView == nil)
  {
      _videoImageView= [[GPUImageView alloc] initWithFrame:self.view.bounds];
      [_videoImageView setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
  }
    return _videoImageView;
}

- (NSMutableDictionary *)videoSettings {
    if (!_videoSettings) {
        _videoSettings = [[NSMutableDictionary alloc] init];
        [_videoSettings setObject:AVVideoCodecH264 forKey:AVVideoCodecKey];
        [_videoSettings setObject:[NSNumber numberWithInteger:LZBImageViewWidth] forKey:AVVideoWidthKey];
        [_videoSettings setObject:[NSNumber numberWithInteger:LZBImageViewHeight] forKey:AVVideoHeightKey];
    }
    return _videoSettings;
}

- (UIButton *)filterButton
{
  if(_filterButton == nil)
  {
      _filterButton =[UIButton buttonWithType:UIButtonTypeCustom];
      [_filterButton addTarget:self action:@selector(filterButtonAction:) forControlEvents:UIControlEventTouchUpInside];
      [_filterButton setImage:[UIImage imageNamed:@"2_1_c_30x30_"] forState:UIControlStateNormal];
      _filterButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
      _filterButton.layer.cornerRadius = filterButton_WithHeight *0.5;
      _filterButton.layer.masksToBounds = YES;
      
  }
    return _filterButton;
}

- (UIButton *)adjustButton
{
  if(_adjustButton == nil)
  {
      _adjustButton =[UIButton buttonWithType:UIButtonTypeCustom];
      [_adjustButton addTarget:self action:@selector(adjustButtonAction:) forControlEvents:UIControlEventTouchUpInside];
      [_adjustButton setImage:[UIImage imageNamed:@"1_1_c_30x30_"] forState:UIControlStateNormal];
      _adjustButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
      _adjustButton.layer.cornerRadius = filterButton_WithHeight *0.5;
      _adjustButton.layer.masksToBounds = YES;
  }
    return _adjustButton;
}

- (NSString *)videoPath
{
  if(_videoPath == nil)
  {
      _videoPath =  [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Movie.mp4"];
  }
    return _videoPath;
}
- (LZBCircleProcessView *)circleView
{
  if(_circleView == nil)
  {
     _circleView = [[LZBCircleProcessView alloc]initWithMaxTime:15 circleSize:CGSizeMake(80, 80) callBackCurrentProcessTime:^(NSInteger current) {
         
     }];
      [_circleView addGestureRecognizer:[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(circleViewLongTouch:)]];
  }
    return _circleView;
}

- (UICollectionView *)collectionView
{
   if(_collectionView == nil)
   {
       UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
       [flowLayout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
       flowLayout.minimumInteritemSpacing = 5;
       flowLayout.sectionInset = UIEdgeInsetsMake(5, 5, 0, 0);
       CGRect frame = CGRectMake([UIScreen mainScreen].bounds.size.width,[UIScreen mainScreen].bounds.size.height -250 , [UIScreen mainScreen].bounds.size.width, collectionViewHeight);
       _collectionView = [[UICollectionView alloc] initWithFrame:frame collectionViewLayout:flowLayout];
       _collectionView.backgroundColor = [UIColor whiteColor];
       _collectionView.delegate = self;
       _collectionView.dataSource = self;
       _collectionView.showsHorizontalScrollIndicator = NO;
       [_collectionView registerClass:[LZBFilterCollectionViewCell class] forCellWithReuseIdentifier:LZBFilterCollectionViewCellID];
   }
    return _collectionView;
}

- (void)initFilterData
{
    __weak typeof(self) weakSelf = self;
    UIImage *orginImage = [UIImage imageNamed:@"kxq_explore_image"];
    NSInteger count = 7;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (NSInteger i = 0;i < count; i++) {
            LZBFilterModel *model = [[LZBFilterModel alloc]init];
            LZBFilterType type = [[LZBFilterHandleTool sharedInstance] getFilterTypeForIndex:i];
            model.filterName = [[LZBFilterHandleTool sharedInstance] getFilterNameWithFilterType:type];
            UIImage *filterImage = [[LZBFilterHandleTool sharedInstance] getFilterImageForOrginImage:orginImage filterType:type];
            model.filterImage = filterImage;
            [weakSelf.filterModels addObject:model];
            if(weakSelf.filterModels.count == count)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.collectionView reloadData];
                });
            }
        }
    });
    
}

- (NSMutableArray *)filterModels
{
  if(_filterModels == nil)
  {
      _filterModels = [NSMutableArray array];
  }
    return _filterModels;
}

- (NSMutableArray<LZBAdjustTableViewCellModel *> *)adjustModels
{
  if(_adjustModels == nil)
  {
      _adjustModels = [NSMutableArray array];
      //1.亮度
      LZBAdjustTableViewCellModel *brightnessModel = [[LZBAdjustTableViewCellModel alloc]init];
      brightnessModel.title = @"亮度";
      brightnessModel.minValue = -1.0;
      brightnessModel.maxValue = 1.0;
      brightnessModel.value = 0.0;
      brightnessModel.adjustType = LZBAdjustType_Brightness;
      [_adjustModels addObject:brightnessModel];
      
      //2.曝光
      LZBAdjustTableViewCellModel *exposuresModel = [[LZBAdjustTableViewCellModel alloc]init];
      exposuresModel.title = @"曝光";
      exposuresModel.minValue = -10.0;
      exposuresModel.maxValue = 10.0;
      exposuresModel.value = 0.0;
      exposuresModel.adjustType = LZBAdjustType_Exposures;
      [_adjustModels addObject:exposuresModel];
      
      //3.对比度
      LZBAdjustTableViewCellModel *contrastModel = [[LZBAdjustTableViewCellModel alloc]init];
      contrastModel.title = @"对比度";
      contrastModel.minValue = 0;
      contrastModel.maxValue = 4.0;
      contrastModel.value = 1.0;
      contrastModel.adjustType = LZBAdjustType_Contrast;
      [_adjustModels addObject:contrastModel];
      
      //4.饱和度
      LZBAdjustTableViewCellModel *saturationModel = [[LZBAdjustTableViewCellModel alloc]init];
      saturationModel.title = @"饱和度";
      saturationModel.minValue = 0;
      saturationModel.maxValue = 2.0;
      saturationModel.value = 1.0;
      saturationModel.adjustType = LZBAdjustType_Saturation;
      [_adjustModels addObject:saturationModel];
     
      //5.灰度
      LZBAdjustTableViewCellModel *gammaModel = [[LZBAdjustTableViewCellModel alloc]init];
      gammaModel.title = @"灰度";
      gammaModel.minValue = 0;
      gammaModel.maxValue = 3.0;
      gammaModel.value = 1.0;
      gammaModel.adjustType = LZBAdjustType_Gamma;
      [_adjustModels addObject:gammaModel];
  }
    return _adjustModels;
}
@end
