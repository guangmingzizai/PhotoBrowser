//
//  PBImageScrollView.m
//  PhotoBrowser
//
//  Created by Moch Xiao on 5/12/16.
//  Copyright © 2016 Moch Xiao. All rights reserved.
//

#import "PBImageScrollView.h"

#define system_version ([UIDevice currentDevice].systemVersion.doubleValue)
#define observe_keypath @"image"

@interface PBImageScrollView ()

@property (nonatomic, strong, readwrite) UIImageView *imageView;
@property (nonatomic, copy, readwrite) PBImageDownloadProgressHandler downloadProgressHandler;
@property (nonatomic, weak) id <NSObject> notification;
@property (nonatomic, strong) CAShapeLayer *progressLayer;

@end

@implementation PBImageScrollView

- (void)dealloc {
    [self _removeObserver];
    [self _removeNotificationIfNeeded];
#if DEBUG
    NSLog(@"~~~~~~~~~~~%s~~~~~~~~~~~", __FUNCTION__);
#endif
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.frame = [UIScreen mainScreen].bounds;
    self.multipleTouchEnabled = YES;
    self.showsVerticalScrollIndicator = YES;
    self.showsHorizontalScrollIndicator = YES;
    self.alwaysBounceVertical = YES;
    self.minimumZoomScale = 1.0f;
    self.maximumZoomScale = 1.0f;
    self.delegate = self;
    
    [self addSubview:self.imageView];
    [self.layer addSublayer:self.progressLayer];
    [self _addObserver];
    [self _addNotificationIfNeeded];
    [self _setupDownloadProgressHandler];
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGPoint center = CGPointMake(CGRectGetWidth(self.bounds) / 2.0, CGRectGetHeight(self.bounds) / 2.0);
    CGRect frame = self.progressLayer.frame;
    frame.origin.x = center.x - CGRectGetWidth(frame) / 2.0f;
    frame.origin.y = center.y - CGRectGetHeight(frame) / 2.0f;
    self.progressLayer.frame = frame;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self _updateFrame];
    [self _recenterImage];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if (![keyPath isEqualToString:observe_keypath]) {
        return;
    }
    if (![object isEqual:self.imageView]) {
        return;
    }

    [self _updateFrame];
    [self _recenterImage];
    [self _setMaximumZoomScale];
}

#pragma mark - Internal Methods

- (void)_handleZoomForLocation:(CGPoint)location {
    CGPoint touchPoint = [self.superview convertPoint:location toView:self.imageView];
    if (self.zoomScale > 1) {
        [self setZoomScale:1 animated:YES];
    } else if (self.maximumZoomScale > 1) {
        CGFloat newZoomScale = self.maximumZoomScale;
        CGFloat horizontalSize = CGRectGetWidth(self.bounds) / newZoomScale;
        CGFloat verticalSize = CGRectGetHeight(self.bounds) / newZoomScale;
        [self zoomToRect:CGRectMake(touchPoint.x - horizontalSize / 2.0f, touchPoint.y - verticalSize / 2.0f, horizontalSize, verticalSize) animated:YES];
    }
}

#pragma mark - Private methods

- (void)_addObserver {
    [self.imageView addObserver:self forKeyPath:observe_keypath options:NSKeyValueObservingOptionNew context:nil];
}

- (void)_removeObserver {
    [self.imageView removeObserver:self forKeyPath:observe_keypath];
}

- (void)_addNotificationIfNeeded {
    if (system_version >= 8.0) {
        return;
    }
    
    __weak typeof(self) weak_self = self;
    self.notification = [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        __strong typeof(weak_self) strong_self = weak_self;
        [strong_self _updateFrame];
        [strong_self _recenterImage];
    }];
}

- (void)_removeNotificationIfNeeded {
    if (system_version >= 8.0) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self.notification];
}

- (void)_updateFrame {
    self.frame = [UIScreen mainScreen].bounds;
    
    UIImage *image = self.imageView.image;
    if (!image) {
        return;
    }
    
    CGSize properSize = [self _properPresentSizeForImage:image];
    self.imageView.frame = CGRectMake(0, 0, properSize.width, properSize.height);
    self.contentSize = properSize;
}

- (CGSize)_properPresentSizeForImage:(UIImage *)image {
    CGFloat ratio = CGRectGetWidth(self.bounds) / image.size.width;
    return CGSizeMake(CGRectGetWidth(self.bounds), ceil(ratio * image.size.height));
}

- (void)_recenterImage {
    CGFloat contentWidth = self.contentSize.width;
    CGFloat horizontalDiff = CGRectGetWidth(self.bounds) - contentWidth;
    CGFloat horizontalAddition = horizontalDiff > 0.f ? horizontalDiff : 0.f;
    
    CGFloat contentHeight = self.contentSize.height;
    CGFloat verticalDiff = CGRectGetHeight(self.bounds) - contentHeight;
    CGFloat verticalAdditon = verticalDiff > 0 ? verticalDiff : 0.f;
    
    self.imageView.center = CGPointMake((contentWidth + horizontalAddition) / 2.0f, (contentHeight + verticalAdditon) / 2.0f);
}

- (void)_setMaximumZoomScale {
    [self setZoomScale:1.0f animated:NO];
    CGSize imageSize = self.imageView.image.size;
    CGFloat selfWidth = CGRectGetWidth(self.bounds);
    CGFloat selfHeight = CGRectGetHeight(self.bounds);
    if (imageSize.width <= selfWidth && imageSize.height <= selfHeight) {
        self.maximumZoomScale = 1.0f;
    } else {
        self.maximumZoomScale = MAX(MIN(imageSize.width / selfWidth, imageSize.height / selfHeight), 3.0f);
    }
}

- (void)_setupDownloadProgressHandler {
    __weak typeof(self) weak_self = self;
    self.downloadProgressHandler = ^(NSInteger receivedSize, NSInteger expectedSize) {
        __strong typeof(weak_self) strong_self = weak_self;
        CGFloat progress = (receivedSize * 1.0f) / (expectedSize * 1.0f);
        strong_self.progressLayer.hidden = NO;
        strong_self.progressLayer.strokeEnd = progress;
        if (progress == 1.0f) {
            strong_self.progressLayer.hidden = YES;
        }
    };
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self _recenterImage];
}

#pragma mark - Accessor

- (UIImageView *)imageView {
    if (!_imageView) {
        _imageView = [UIImageView new];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
    }
    return _imageView;
}

- (CAShapeLayer *)progressLayer {
    if (!_progressLayer) {
        _progressLayer = [CAShapeLayer layer];
        _progressLayer.frame = CGRectMake(0, 0, 40, 40);
        _progressLayer.cornerRadius = 20;
        _progressLayer.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5].CGColor;
        
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_progressLayer.bounds, 7, 7) cornerRadius:(40 / 2.0f - 7)];
        _progressLayer.path = path.CGPath;
        _progressLayer.fillColor = [UIColor clearColor].CGColor;
        _progressLayer.strokeColor = [UIColor whiteColor].CGColor;
        _progressLayer.lineWidth = 4;
        _progressLayer.lineCap = kCALineCapRound;
        _progressLayer.strokeStart = 0;
        _progressLayer.strokeEnd = 0;
        _progressLayer.hidden = YES;
    }
    return _progressLayer;
}

@end
