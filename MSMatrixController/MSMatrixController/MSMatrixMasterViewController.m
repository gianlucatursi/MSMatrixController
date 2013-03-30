//
//  Created by marco on 29/03/13.
//
//
//

#import <CoreGraphics/CoreGraphics.h>
#import "MSMatrixMasterViewController.h"
#import "MSMatrixView.h"
#import "MSPanGestureRecognizer.h"

#define alphaHiddenControllers 0.4

@interface MSMatrixMasterViewController ()
@property(strong, nonatomic) MSPanGestureRecognizer *panGestureRecognizer;
@property(assign, nonatomic) CGPoint positionBeforePan;
@property(assign, nonatomic) MSPanWay lastPanningWay;
@end

@implementation MSMatrixMasterViewController

- (id)initWithFrame:(CGRect)frame
{
  self = [super init];
  if (self) {
    self.view = [[MSMatrixView alloc] initWithFrame:frame];
    return self;
  }
  return nil;
}

- (void)setChildren:(NSArray *)children
{
  _childrenViewControllers = children;

  NSInteger maxRows = 0;
  NSInteger maxCols = 0;
  CGFloat screenWidth = self.view.frame.size.width;
  CGFloat screenHeight = self.view.frame.size.height;
  for (UIViewController *child in _childrenViewControllers) {

    maxRows = MAX(maxRows, child.row);
    maxCols = MAX(maxCols, child.col);

    Position left = child.position;
    left.col = left.col - 1;
    Position right = child.position;
    right.col = right.col + 1;
    Position top = child.position;
    top.row = top.row - 1;
    Position bottom = child.position;
    bottom.row = bottom.row + 1;

    child.leftViewController = [self getControllerAtPosition:left];
    child.rightViewController = [self getControllerAtPosition:right];
    child.topViewController = [self getControllerAtPosition:top];
    child.bottomViewController = [self getControllerAtPosition:bottom];

    CGRect frameInsideMasterView = child.view.frame;
    frameInsideMasterView.origin.x = screenWidth * child.col;
    frameInsideMasterView.origin.y = screenHeight * child.row;
    child.view.frame = frameInsideMasterView;
  }

  CGSize contentSize = CGSizeMake(screenWidth * (maxCols + 1), screenHeight * (maxRows + 1));
  CGRect frame = self.view.frame;
  frame.size = contentSize;
  self.view.frame = frame;

  for (UIViewController *child in _childrenViewControllers) {
    [self addChildViewController:child];
    [self.view addSubview:child.view];
    [child didMoveToParentViewController:self];
  }

  _panGestureRecognizer = [[MSPanGestureRecognizer alloc] initWithTarget:self action:@selector(panDetected:)];
  [self.view addGestureRecognizer:_panGestureRecognizer];

  _visibleViewController = [_childrenViewControllers objectAtIndex:0];
}

- (UIViewController *)getControllerAtPosition:(Position)position
{
  NSPredicate *positionPredicate = [NSPredicate predicateWithFormat:@"row == %d AND col == %d", position.row, position.col];
  NSArray *viewControllersWithMatchedPosition = [_childrenViewControllers filteredArrayUsingPredicate:positionPredicate];
  if (viewControllersWithMatchedPosition.count == 0) {
    return nil;
  }
  return [viewControllersWithMatchedPosition objectAtIndex:0];
}

- (void)panDetected:(MSPanGestureRecognizer *)pan
{
  if (pan.state == UIGestureRecognizerStateBegan) {
    _positionBeforePan = self.view.frame.origin;
    _lastPanningWay = pan.way;
  }
  else if (pan.state == UIGestureRecognizerStateChanged) {
    [self handlePanWithDirection:pan.direction way:pan.way velocity:[pan velocityInView:self.view] translation:[pan translationInView:self.view]];
  }
  else if (pan.state == UIGestureRecognizerStateEnded) {
    [self handleEndedPanWithDirection:pan.direction translation:[pan translationInView:self.view] velocity:[pan velocityInView:self.view]];
  }
}

- (void)handlePanWithDirection:(MSPanDirection)direction way:(MSPanWay)way velocity:(CGPoint)velocity translation:(CGPoint)translation
{
  if (_lastPanningWay != way) {
    return;
  }

  if (way == MSPanWayHorizontal) {
    translation.y = 0;
  }
  else if (way == MSPanWayVertical) {
    translation.x = 0;
  }
  else {
    return;
  }

  CGRect frame = self.view.frame;
  CGPoint newOrigin;
  newOrigin.x = _positionBeforePan.x + translation.x;
  newOrigin.y = _positionBeforePan.y + translation.y;
  frame.origin = newOrigin;
  self.view.frame = frame;

  // TODO: change alpha value
  UIViewController *destinationViewController;
  CGFloat movedPoints = 0;
  CGFloat totalPoints = 0;
  if (direction == MSPanDirectionLeft) {
    totalPoints = _visibleViewController.view.frame.size.width;
    movedPoints = fabsf(translation.x);
    destinationViewController = _visibleViewController.leftViewController;
  }
  else if (direction == MSPanDirectionRight) {
    totalPoints = _visibleViewController.view.frame.size.width;
    movedPoints = fabsf(translation.x);
    destinationViewController = _visibleViewController.rightViewController;
  }
  else if (direction == MSPanDirectionUp) {
    totalPoints = _visibleViewController.view.frame.size.height;
    movedPoints = fabsf(translation.y);
    destinationViewController = _visibleViewController.topViewController;
  }
  else if (direction == MSPanDirectionDown) {
    totalPoints = _visibleViewController.view.frame.size.height;
    movedPoints = fabsf(translation.y);
    destinationViewController = _visibleViewController.bottomViewController;
  }
  float alphaValue = movedPoints / totalPoints;
  destinationViewController.view.alpha = alphaHiddenControllers + alphaValue;
  _visibleViewController.view.alpha = alphaHiddenControllers + fabsf(1 - alphaValue);
}

- (void)handleEndedPanWithDirection:(MSPanDirection)direction translation:(CGPoint)translation velocity:(CGPoint)velocity
{
  const CGFloat horizontalThreshold = _visibleViewController.view.frame.size.width / 4;
  const CGFloat verticalThreshold = _visibleViewController.view.frame.size.height / 4;
  const CGFloat velocityThreshold = 1000;

  BOOL nextControllerExists = NO;
  nextControllerExists |= direction == MSPanDirectionRight && _visibleViewController.rightViewController;
  nextControllerExists |= direction == MSPanDirectionLeft && _visibleViewController.leftViewController;
  nextControllerExists |= direction == MSPanDirectionUp && _visibleViewController.topViewController;
  nextControllerExists |= direction == MSPanDirectionDown && _visibleViewController.bottomViewController;

  BOOL overHorizontalThreshold = fabs(translation.x) > horizontalThreshold;
  BOOL overVerticalThreshold = fabs(translation.y) > verticalThreshold;
  BOOL overVelocityXThreshold = fabs(velocity.x) > velocityThreshold;
  BOOL overVelocityYThreshold = fabs(velocity.y) > velocityThreshold;


  if (!nextControllerExists) {
    [self goToViewController:_visibleViewController translation:translation velocity:CGPointZero way:MSPanWayNone];
    return;
  }

  NSLog(@"velocity x %f y %f", velocity.x, velocity.y);

  if (overHorizontalThreshold || overVelocityXThreshold) {
    NSLog(@"X axis");
    if (direction == MSPanDirectionLeft) {
      NSLog(@"goto left controller");
      [self goToViewController:_visibleViewController.leftViewController translation:translation velocity:velocity way:MSPanWayHorizontal];
    }
    else if (direction == MSPanDirectionRight) {
      NSLog(@"goto right controller");
      [self goToViewController:_visibleViewController.rightViewController translation:translation velocity:velocity way:MSPanWayHorizontal];
    }
  }
  else if (overVerticalThreshold || overVelocityYThreshold) {
    NSLog(@"Y axis");
    if (direction == MSPanDirectionUp) {
      NSLog(@"goto top controller");
      [self goToViewController:_visibleViewController.topViewController translation:translation velocity:velocity way:MSPanWayVertical];
    }
    else if (direction == MSPanDirectionDown) {
      NSLog(@"goto bottom controller");
      [self goToViewController:_visibleViewController.bottomViewController translation:translation velocity:velocity way:MSPanWayVertical];
    }
  }
  else {
    NSLog(@"go to original view controller");
    [self goToViewController:_visibleViewController translation:translation velocity:CGPointZero way:MSPanWayNone];
  }
}

- (void)goToViewController:(UIViewController *)newController translation:(CGPoint)translation velocity:(CGPoint)velocity way:(MSPanWay)way
{
  NSTimeInterval velocityAnimation = INT_MAX;
  if (way == MSPanWayHorizontal) {
    CGFloat points = fabsf(_visibleViewController.view.frame.size.width - (CGFloat)fabs(translation.x));
    CGFloat panVelocity = fabsf(velocity.x);
    if (panVelocity > 0) {
      velocityAnimation = points / panVelocity;
    }
  }
  else {
    CGFloat points = fabsf(translation.y);
    CGFloat panVelocity = fabsf(_visibleViewController.view.frame.size.height - (CGFloat)fabs(velocity.y));
    if (panVelocity > 0) {
      velocityAnimation = points / panVelocity;
    }
  }
  NSLog(@"velocity %f", velocityAnimation);
  velocityAnimation = MAX(0.3, MIN(velocityAnimation, 0.7));
  NSLog(@"velocity %f", velocityAnimation);

  [UIView animateWithDuration:velocityAnimation animations:^{
    CGRect frameForVisibleViewController = self.view.frame;
    frameForVisibleViewController.origin.x = -newController.view.frame.origin.x;
    frameForVisibleViewController.origin.y = -newController.view.frame.origin.y + 20;
    self.view.frame = frameForVisibleViewController;

    if (_visibleViewController != newController) {
      _visibleViewController.view.alpha = alphaHiddenControllers;
      newController.view.alpha = 1.0;
    }
    else {
      _visibleViewController.view.alpha = 1.0;
    }
  }                completion:^(BOOL finished) {
    if (finished) {
      _visibleViewController = newController;
      [_delegate didMoveToViewController:newController atPosition:newController.position];
    }
  }];
}

@end