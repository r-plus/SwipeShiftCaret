#import <UIKit/UIKit.h>

%config(generator=internal);

#define PREF_PATH @"/var/mobile/Library/Preferences/jp.r-plus.SwipeShiftCaret.plist"

static UIView *tv;
static BOOL panGestureEnabled;

@interface UIView (Private) <UITextInput>
@end

@interface SCSwipeGestureRecognizer : UISwipeGestureRecognizer
@end

@implementation SCSwipeGestureRecognizer
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)gesture {
  if ([gesture isMemberOfClass:[SCSwipeGestureRecognizer class]])
    return YES;
  return NO;
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)gesture {
  if ([gesture isKindOfClass:[UISwipeGestureRecognizer class]] &&
      // Don't prevent SwipeNav
      ![gesture isMemberOfClass:%c(SNSwipeGestureRecognizer)])
    return YES;
  return NO;
}
@end

@interface SCPanGestureRecognizer : UIPanGestureRecognizer
@end

@implementation SCPanGestureRecognizer
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)gesture {
  if ([gesture isMemberOfClass:[SCPanGestureRecognizer class]])
    return YES;
  return NO;
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)gesture {
  if (([gesture isMemberOfClass:[SCPanGestureRecognizer class]] ||
      [gesture isKindOfClass:[UISwipeGestureRecognizer class]]) &&
      // Don't prevent SwipeNav
      ![gesture isMemberOfClass:%c(SNSwipeGestureRecognizer)])
    return YES;
  return NO;
}
@end

static void InstallSwipeGestureRecognizer()
{
  if ([tv isKindOfClass:[UIView class]]) {
    SCSwipeGestureRecognizer *rightSwipeShiftCaret = [[SCSwipeGestureRecognizer alloc] initWithTarget:tv action:@selector(rightSwipeShiftCaret:)];
    rightSwipeShiftCaret.direction = UISwipeGestureRecognizerDirectionRight;
    [tv addGestureRecognizer:rightSwipeShiftCaret];
    [rightSwipeShiftCaret release];

    SCSwipeGestureRecognizer *leftSwipeShiftCaret = [[SCSwipeGestureRecognizer alloc] initWithTarget:tv action:@selector(leftSwipeShiftCaret:)];
    leftSwipeShiftCaret.direction = UISwipeGestureRecognizerDirectionLeft;
    [tv addGestureRecognizer:leftSwipeShiftCaret];
    [leftSwipeShiftCaret release];
  }
}

static void InstallPanGestureRecognizer()
{
  if ([tv isKindOfClass:[UIView class]]) {
    SCPanGestureRecognizer *pan = [[SCPanGestureRecognizer alloc] initWithTarget:tv action:@selector(SCPanGestureDidPan:)];
    pan.cancelsTouchesInView = NO;
    [tv addGestureRecognizer:pan];
    [pan release];
  }
}

static void ShiftCaret(BOOL isLeftSwipe)
{
  if (panGestureEnabled)
    return;

  UITextPosition *position = nil;
  if ([tv respondsToSelector:@selector(positionFromPosition:inDirection:offset:)])
    position = isLeftSwipe ? [tv positionFromPosition:tv.selectedTextRange.start inDirection:UITextLayoutDirectionLeft offset:1]
      : [tv positionFromPosition:tv.selectedTextRange.end inDirection:UITextLayoutDirectionRight offset:1];
  // failsafe for over edge position crash.
  if (!position)
    return;
  UITextRange *range = [tv textRangeFromPosition:position toPosition:position];
  [tv setSelectedTextRange:range];
}

%hook UIView
- (BOOL)becomeFirstResponder
{
  BOOL tmp = %orig;
  if (tmp && [self respondsToSelector:@selector(setSelectedTextRange:)]) {
    tv = self;
    if (panGestureEnabled)
      InstallPanGestureRecognizer();
    else
      InstallSwipeGestureRecognizer();
  }
  return tmp;
}

%new(v@:@)
- (void)leftSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  ShiftCaret(YES);
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  ShiftCaret(NO);
}

// based code is SwipeSelection.
%new(v@:@)
- (void)SCPanGestureDidPan:(UIPanGestureRecognizer *)sender
{
  if (!panGestureEnabled)
    return;

  static BOOL hasStarted = NO;
  static UITextPosition *startTextPosition;

  if (sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateCancelled) {
    hasStarted = NO;
    sender.cancelsTouchesInView = NO;
    [startTextPosition release];
    startTextPosition = nil;
  } else if (sender.state == UIGestureRecognizerStateBegan) {
    if ([tv respondsToSelector:@selector(positionFromPosition:offset:)])
      startTextPosition = [tv.selectedTextRange.start retain];
  } else if (sender.state == UIGestureRecognizerStateChanged) {
    CGPoint offset = [sender translationInView:self];
    if (!hasStarted && offset.x < 5 && offset.x > -5)
      return;
    sender.cancelsTouchesInView = YES;
    hasStarted = YES;
    int scale = 16;
    int pointsChanged = offset.x / scale;

    UITextPosition *position = nil;
    if ([tv respondsToSelector:@selector(positionFromPosition:inDirection:offset:)])
      position = pointsChanged < 0 ? [tv positionFromPosition:startTextPosition inDirection:UITextLayoutDirectionLeft offset:-pointsChanged]
        : [tv positionFromPosition:startTextPosition inDirection:UITextLayoutDirectionRight offset:pointsChanged];
    // failsafe for over edge position crash.
    if (!position)
      return;
    UITextRange *range = [tv textRangeFromPosition:position toPosition:position];
    [tv setSelectedTextRange:range];
  }
}
%end

static void LoadSettings()
{	
  NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
  id existPanGesture = [dict objectForKey:@"PanGestureEnabled"];
  panGestureEnabled = existPanGesture ? [existPanGesture boolValue] : YES;
  if (panGestureEnabled)
    InstallPanGestureRecognizer();
  else
    InstallSwipeGestureRecognizer();
}

static void PostNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
  LoadSettings();
}

%ctor
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PostNotification, CFSTR("jp.r-plus.swipeshiftcaret.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
  LoadSettings();
  [pool drain];
}
