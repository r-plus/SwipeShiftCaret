#import <UIKit/UIKit.h>
#import <SpringBoard/SpringBoard.h>
#import <notify.h>
#import <libactivator/libactivator.h>
#import <CaptainHook/CaptainHook.h>

%config(generator=internal);

#define kLeft "jp.r-plus.leftshiftcaret"
#define kRight "jp.r-plus.rightshiftcaret"

// UIView for PanGesture.
static UIView *tv;
// MutableSet for SwipeGesture and Activator.
static NSMutableSet *textViews;
static int notifyToken;
static BOOL isActive;
static BOOL orientationRotating = NO;

@interface UIView (Private) <UITextInput>
- (BOOL)isEditable;
- (NSRange)selectedRange;
- (NSRange)selectionRange;
- (NSString *)text;
- (void)setSelectionRange:(NSRange)range;
- (void)setSelectedRange:(NSRange)range;
@end

@interface ActShiftCaret : NSObject <LAListener>
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
  if ([gesture isMemberOfClass:[SCSwipeGestureRecognizer class]])
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
  if ([gesture isMemberOfClass:[SCPanGestureRecognizer class]])
    return YES;
  return NO;
}
@end

static inline int GetEditingTextViewsCount()
{
  int count = 0;
  for (UIView *tv in [[textViews copy] autorelease])
    if ([tv respondsToSelector:@selector(isEditable)])
      if ([tv isEditable])
        count++;
  return count;
}

static void InstallSwipeGestureRecognizer()
{
  for (UIView *tv in [[textViews copy] autorelease]) {
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
  for (UIView *tv in [[textViews copy] autorelease]) {
    UITextPosition *position = nil;
    if ([tv respondsToSelector:@selector(positionFromPosition:inDirection:offset:)])
      position = isLeftSwipe ? [tv positionFromPosition:tv.selectedTextRange.start inDirection:UITextLayoutDirectionLeft offset:1]
        : [tv positionFromPosition:tv.selectedTextRange.end inDirection:UITextLayoutDirectionRight offset:1];
    // failsafe for over edge position crash.
    if (!position)
      continue;
    UITextRange *range = [tv textRangeFromPosition:position toPosition:position];
    [tv setSelectedTextRange:range];
  }
}

static void LeftShiftCaretNotificationReceived(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
  ShiftCaret(YES);
}

static void RightShiftCaretNotificationReceived(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
  ShiftCaret(NO);
}

// NOTE: Keyboard Will/Did ShowNotification isnt call if iPad split keyboard.
static void KeyboardWillShowNotificationReceived(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
  if ([textViews count]) {
    InstallPanGestureRecognizer();
    //InstallSwipeGestureRecognizer();
  }
  notify_set_state(notifyToken, GetEditingTextViewsCount());
}

static void KeyboardWillHideNotificationReceived(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
  NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
  if (!orientationRotating && ![identifier isEqualToString:@"com.google.Gmail"]) {
    // mobilesafari doesnt call becomeFirstResponder method after google search from webview.
    if (![identifier isEqualToString:@"com.apple.mobilesafari"]) {
      [textViews removeAllObjects];
      notify_set_state(notifyToken, GetEditingTextViewsCount());
    }
  }
}

static void WillEnterForegroundNotificationReceived(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
  notify_set_state(notifyToken, GetEditingTextViewsCount());
  if (!isActive) {
    isActive = YES;
    CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(darwin, LeftShiftCaretNotificationReceived, LeftShiftCaretNotificationReceived, CFSTR(kLeft), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(darwin, RightShiftCaretNotificationReceived, RightShiftCaretNotificationReceived, CFSTR(kRight), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), KeyboardWillShowNotificationReceived, KeyboardWillShowNotificationReceived, (CFStringRef)UIKeyboardWillShowNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), KeyboardWillHideNotificationReceived, KeyboardWillHideNotificationReceived, (CFStringRef)UIKeyboardWillHideNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
  }
}

static void DidEnterBackgroundNotificationReceived(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
  if (isActive) {
    isActive = NO;
    CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterRemoveObserver(darwin, LeftShiftCaretNotificationReceived, CFSTR(kLeft), NULL);
    CFNotificationCenterRemoveObserver(darwin, RightShiftCaretNotificationReceived, CFSTR(kRight), NULL);
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetLocalCenter(), KeyboardWillShowNotificationReceived, (CFStringRef)UIKeyboardWillShowNotification, NULL);
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetLocalCenter(), KeyboardWillHideNotificationReceived, (CFStringRef)UIKeyboardWillHideNotification, NULL);
  }
}

%hook UIView
- (BOOL)becomeFirstResponder
{
  BOOL tmp = %orig;
  if (tmp && [self respondsToSelector:@selector(setSelectedTextRange:)]) {
    [textViews addObject:self];
    tv = self;
    notify_set_state(notifyToken, GetEditingTextViewsCount());
    InstallPanGestureRecognizer();
    //InstallSwipeGestureRecognizer();
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

// get orientationRotating status for prevent removeAllObjects.
%hook UIViewController
- (void)_willRotateToInterfaceOrientation:(int)arg1 duration:(double)arg2 forwardToChildControllers:(BOOL)arg3 skipSelf:(BOOL)arg4
{
  orientationRotating = YES;
  %orig;
}

- (void)_didRotateFromInterfaceOrientation:(int)arg1 forwardToChildControllers:(BOOL)arg2 skipSelf:(BOOL)arg3
{
  orientationRotating = NO;
  %orig;
}
%end

@implementation ActShiftCaret
+ (void)load
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  notify_register_check("com.r-plus.swipeshiftcaret", &notifyToken);
  if (LASharedActivator.runningInsideSpringBoard) {
    ActShiftCaret *shiftcaret = [[self alloc] init];
    [LASharedActivator registerListener:shiftcaret forName:@kLeft];
    [LASharedActivator registerListener:shiftcaret forName:@kRight];
    WillEnterForegroundNotificationReceived(nil, nil, nil, nil, nil);
  } else {
    CFNotificationCenterRef local = CFNotificationCenterGetLocalCenter();
    CFNotificationCenterAddObserver(local, WillEnterForegroundNotificationReceived, WillEnterForegroundNotificationReceived, (CFStringRef)UIApplicationDidFinishLaunchingNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(local, WillEnterForegroundNotificationReceived, WillEnterForegroundNotificationReceived, (CFStringRef)UIApplicationWillEnterForegroundNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(local, DidEnterBackgroundNotificationReceived, DidEnterBackgroundNotificationReceived, (CFStringRef)UIApplicationDidEnterBackgroundNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(local, KeyboardWillShowNotificationReceived, KeyboardWillShowNotificationReceived, (CFStringRef)UIKeyboardWillShowNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(local, KeyboardWillHideNotificationReceived, KeyboardWillHideNotificationReceived, (CFStringRef)UIKeyboardWillHideNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
  }
  textViews = [[NSMutableSet alloc] init];
  [pool drain];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event forListenerName:(NSString *)listenerName
{
  if ([(SpringBoard *)UIApp _accessibilityFrontMostApplication]) {
    uint64_t state = 0;
    notify_get_state(notifyToken, &state);
    if (state) {
      if ([listenerName isEqualToString:@kLeft])
        notify_post(kLeft);
      else if ([listenerName isEqualToString:@kRight])
        notify_post(kRight);

      // prevent iOS default behavior.
      event.handled = YES;
    }
  } else {
    // NOTE: activator method always call from SpringBoard.
    //       So cannot use app's [textViews count] for this handle.
    if ([textViews count]) {
      if ([listenerName isEqualToString:@kLeft])
        notify_post(kLeft);
      else if ([listenerName isEqualToString:@kRight])
        notify_post(kRight);

      event.handled = YES;
    }
  }
}
@end
