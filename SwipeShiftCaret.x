#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

%config(generator=internal);

#define PREF_PATH @"/var/mobile/Library/Preferences/jp.r-plus.SwipeShiftCaret.plist"

static UIView *tv;
static BOOL panGestureEnabled;
static BOOL caretMagnifierIsEnabled;
static BOOL fasterByVelocityIsEnabled;
static BOOL isSelectionMode = NO;

@interface UIView (Private) <UITextInput>
- (NSRange)selectedRange;
- (NSRange)selectionRange;
- (void)setSelectedRange:(NSRange)range;
- (void)setSelectionRange:(NSRange)range;
- (void)scrollSelectionToVisible:(BOOL)arg1;
- (CGRect)rectForSelection:(NSRange)range;
- (CGRect)textRectForBounds:(CGRect)rect;
- (id)content;
@property(copy) NSString *text;
@end

@interface UIKeyboardImpl : NSObject
+ (id)sharedInstance;
- (BOOL)callLayoutIsShiftKeyBeingHeld;
@end

@interface UIFieldEditor : NSObject
+ (id)sharedFieldEditor;
- (void)revealSelection;
@end

@interface UIKeyboardLayoutStar : NSObject
- (UIKBKey *)keyHitTest:(CGPoint)arg;
- (NSString *)displayString;
@end

@interface UITextMagnifierCaret : UIView
+ (id)sharedCaretMagnifier;
- (void)zoomUpAnimation;
- (void)zoomDownAnimation;
- (void)stopMagnifying:(BOOL)arg1;
- (void)setToMagnifierRenderer;
- (void)setOffset:(CGPoint)arg1;
- (void)setMagnificationPoint:(CGPoint)arg1;
- (void)setText:(id)arg1;
- (void)setTarget:(id)arg1;
@end

@interface UITextMagnifierRanged : UIView
+ (id)sharedRangedMagnifier;
- (void)stopMagnifying:(BOOL)arg1;
@end

@interface UITextEffectsWindow : NSObject
+ (id)sharedTextEffectsWindowAboveStatusBar;
@end

@interface SCSwipeGestureRecognizer : UISwipeGestureRecognizer
@end

@implementation SCSwipeGestureRecognizer
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)gesture {
  if ([gesture isKindOfClass:[UIPanGestureRecognizer class]] &&
      ![gesture.view isKindOfClass:%c(CKMessageEntryView)] &&
      ![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.google.Gmail"])
    self.state = UIGestureRecognizerStateFailed;
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
  if ([gesture isKindOfClass:[UIPanGestureRecognizer class]] &&
      ![gesture.view isKindOfClass:%c(CKMessageEntryView)] &&
      ![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.google.Gmail"])
    self.state = UIGestureRecognizerStateCancelled;
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
    for (UIGestureRecognizer *gesture in [tv gestureRecognizers])
      if ([gesture isMemberOfClass:[SCPanGestureRecognizer class]])
        [tv removeGestureRecognizer:gesture];

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

  if ([tv respondsToSelector:@selector(positionFromPosition:inDirection:offset:)]) {
    UITextPosition *position = nil;
    position = isLeftSwipe ? [tv positionFromPosition:tv.selectedTextRange.start inDirection:UITextLayoutDirectionLeft offset:1]
      : [tv positionFromPosition:tv.selectedTextRange.end inDirection:UITextLayoutDirectionRight offset:1];
    // failsafe for over edge position crash.
    if (!position)
      return;
    UITextRange *range = [tv textRangeFromPosition:position toPosition:position];
    tv.selectedTextRange = range;
  } else {
    // for iOS 4
    NSRange currentRange;
    if ([tv respondsToSelector:@selector(selectionRange)])
      currentRange = [tv selectionRange];
    else if ([tv respondsToSelector:@selector(selectedRange)])
      currentRange = [tv selectedRange];

    NSInteger location = isLeftSwipe ? --currentRange.location : ++currentRange.location;
    if (location < 0)
      location = 0;
    else if (location > tv.text.length)
      location = tv.text.length;

    NSRange range = NSMakeRange(location, 0);
    if ([tv respondsToSelector:@selector(setSelectedRange:)])
      [tv setSelectedRange:range];
    else if ([tv respondsToSelector:@selector(setSelectionRange:)])
      [tv setSelectionRange:range];
  }

  // reveal for UITextField.
  [[%c(UIFieldEditor) sharedFieldEditor] revealSelection];
  // reveal for UITextView, UITextContentView and UIWebDocumentView.
  if ([tv respondsToSelector:@selector(scrollSelectionToVisible:)])
    [tv scrollSelectionToVisible:YES];
}

static void PopupMenu(CGRect rect)
{
  UIMenuController *mc = [UIMenuController sharedMenuController];
  [mc setTargetRect:rect inView:tv];
  [mc setMenuVisible:YES animated:YES];
}

%hook UIKeyboardLayoutStar
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  %orig;
  UITouch *touch = [touches anyObject];
  UIKBKey *kb = [self keyHitTest:[touch locationInView:touch.view]];
  NSString *kbString = [kb displayString];
  if ([kbString isEqualToString:@"あいう"] ||
      [kbString isEqualToString:@"ABC"] ||
      [kbString isEqualToString:@"☆123"] ||
      [kbString isEqualToString:@"123"])
    isSelectionMode = YES;
  else
    isSelectionMode = NO;
}

- (void)touchesCancelled:(id)arg1 withEvent:(id)arg2
{
  %orig;
  isSelectionMode = NO;
}

- (void)touchesEnded:(id)arg1 withEvent:(id)arg2
{
  %orig;
  isSelectionMode = NO;
}
%end

%hook UIView
- (BOOL)becomeFirstResponder
{
  BOOL tmp = %orig;
  if (tmp && ([self respondsToSelector:@selector(setSelectedTextRange:)] ||
       [self respondsToSelector:@selector(setSelectedRange:)] ||
       [self respondsToSelector:@selector(setSelectionRange:)])) {
    tv = self;
    if (panGestureEnabled)
      InstallPanGestureRecognizer();
    else
      InstallSwipeGestureRecognizer();
  }
  return tmp;
}

- (BOOL)resignFirstResponder
{
  if (tv == self)
    tv = nil;
  return %orig;
}

%new(v@:@)
- (void)leftSwipeShiftCaret:(UISwipeGestureRecognizer *)gesture
{
  ShiftCaret(YES);
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)gesture
{
  ShiftCaret(NO);
}

// based code is SwipeSelection.
%new(v@:@)
- (void)SCPanGestureDidPan:(UIPanGestureRecognizer *)gesture
{
  if (!panGestureEnabled)
    return;

  static BOOL zoomUpAnimationStarted = NO;
  static BOOL hasStarted = NO;
  static BOOL isLeftPanning = YES;
  static UITextRange *startTextRange;
  static NSRange startRange;
  static int numberOfTouches = 0;
  static CGPoint prevVelo;

  int touchesCount = [gesture numberOfTouches];
  if (touchesCount > numberOfTouches)
    numberOfTouches = touchesCount;

  UIKeyboardImpl *keyboardImpl = [%c(UIKeyboardImpl) sharedInstance];
  if ([keyboardImpl respondsToSelector:@selector(callLayoutIsShiftKeyBeingHeld)] && !isSelectionMode)
    isSelectionMode = [keyboardImpl callLayoutIsShiftKeyBeingHeld];

  if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
    // cleanup
    numberOfTouches = 0;
    prevVelo = CGPointMake(0,0);
    isLeftPanning = YES;
    gesture.cancelsTouchesInView = NO;
    if ([tv respondsToSelector:@selector(positionFromPosition:inDirection:offset:)])
      [startTextRange release];
    startTextRange = nil;

    if (caretMagnifierIsEnabled) {
      zoomUpAnimationStarted = NO;
      [[%c(UITextMagnifierRanged) sharedRangedMagnifier] stopMagnifying:YES];
      [[%c(UITextMagnifierCaret) sharedCaretMagnifier] zoomDownAnimation];
    }

    // reveal for UITextView, UITextContentView and UIWebDocumentView.
    if ([tv respondsToSelector:@selector(scrollSelectionToVisible:)] && hasStarted)
      [tv scrollSelectionToVisible:YES];
    hasStarted = NO;

    // auto pop-up menu.
    if ([tv respondsToSelector:@selector(selectedTextRange)]) {
      UITextRange *range = tv.selectedTextRange;
      if (range && !range.isEmpty)
        PopupMenu([tv firstRectForRange:range]);
    } else if ([tv respondsToSelector:@selector(rectForSelection:)]) {
      NSRange range = [tv selectedRange];
      // TODO: more better rect.
      if (range.length)
        PopupMenu([tv rectForSelection:range]);
    } else if ([tv respondsToSelector:@selector(textRectForBounds:)]) {
      NSRange range = [tv selectionRange];
      // TODO: more better rect.
      if (range.length)
        PopupMenu([tv textRectForBounds:tv.bounds]);
    }

  } else if (gesture.state == UIGestureRecognizerStateBegan) {

    if ([tv respondsToSelector:@selector(positionFromPosition:inDirection:offset:)])
      startTextRange = [tv.selectedTextRange retain];
    else if ([tv respondsToSelector:@selector(selectedRange)])
      startRange = [tv selectedRange];
    else if ([tv respondsToSelector:@selector(selectionRange)])
      startRange = [tv selectionRange];

  } else if (gesture.state == UIGestureRecognizerStateChanged) {

    CGPoint offset = [gesture translationInView:self];
    if (!hasStarted && abs(offset.x) < 16)
      return;
    if (!hasStarted && abs(offset.x) < abs(offset.y)) {
      gesture.state = UIGestureRecognizerStateEnded;
      return;
    }
    if (!hasStarted)
      isLeftPanning = offset.x < 0 ? YES : NO;
    gesture.cancelsTouchesInView = YES;
    hasStarted = YES;
    if (fasterByVelocityIsEnabled) {
      CGPoint velo = [gesture velocityInView:self];
      if (abs(prevVelo.x) < 1000 && abs(velo.x) / 1000 != 0)
        numberOfTouches += (abs(velo.x) / 1000);
      prevVelo = velo;
    }
    int scale = 16 / numberOfTouches ? : 1;
    int pointsChanged = offset.x / scale;


    // for iOS 5+ and UIWebDocumentView 4+
    if ([tv respondsToSelector:@selector(positionFromPosition:inDirection:offset:)]) {
      UITextPosition *position = nil;
      if ([tv respondsToSelector:@selector(positionFromPosition:inDirection:offset:)]) {
        if (startTextRange.isEmpty)
          position = [tv positionFromPosition:startTextRange.start
            inDirection:pointsChanged < 0 ? UITextLayoutDirectionLeft : UITextLayoutDirectionRight
            offset:abs(pointsChanged)];
        else
          position = [tv positionFromPosition:isLeftPanning ? startTextRange.start : startTextRange.end
            inDirection:pointsChanged < 0 ? UITextLayoutDirectionLeft : UITextLayoutDirectionRight
            offset:abs(pointsChanged)];
      }
      // failsafe for over edge position crash.
      if (!position)
        return;

      // CaretMagnifier
      if (caretMagnifierIsEnabled) {
        id magni = [%c(UITextMagnifierCaret) sharedCaretMagnifier];
        UITextPosition *positionForMagnifier;
        int changedOffsetFromBeginningOfDocument = [self offsetFromPosition:self.beginningOfDocument toPosition:position];
        if (startTextRange.isEmpty) {
          int offsetFromBeginningOfDocument = [self offsetFromPosition:self.beginningOfDocument toPosition:startTextRange.start];
          if (offsetFromBeginningOfDocument > changedOffsetFromBeginningOfDocument)
            positionForMagnifier = self.selectedTextRange.start;
          else
            positionForMagnifier = self.selectedTextRange.end;
        } else {
          if (isLeftPanning) {
            int offsetFromBeginningOfDocumentToSelectedEnd = [self offsetFromPosition:self.beginningOfDocument toPosition:startTextRange.end];
            if (offsetFromBeginningOfDocumentToSelectedEnd > changedOffsetFromBeginningOfDocument)
              positionForMagnifier = self.selectedTextRange.start;
            else
              positionForMagnifier = self.selectedTextRange.end;
          } else {
            int offsetFromBeginningOfDocumentToSelectedStart = [self offsetFromPosition:self.beginningOfDocument toPosition:startTextRange.start];
            if (offsetFromBeginningOfDocumentToSelectedStart > changedOffsetFromBeginningOfDocument)
              positionForMagnifier = self.selectedTextRange.start;
            else
              positionForMagnifier = self.selectedTextRange.end;
          }
        }
        CGRect caretRect = [self caretRectForPosition:positionForMagnifier];
        CGPoint caretPoint = caretRect.origin;
        [magni setTarget:tv];
        if ([tv respondsToSelector:@selector(content)])
          [magni setText:[tv content]];
        [magni setToMagnifierRenderer];
        [[%c(UITextEffectsWindow) sharedTextEffectsWindowAboveStatusBar] addSubview:magni];
        [magni setMagnificationPoint:caretPoint];
        [magni setOffset:CGPointMake(0.0f,20.0f)];
        if (!zoomUpAnimationStarted) {
          [magni zoomUpAnimation];
          zoomUpAnimationStarted = YES;
        }
      }

      // ShiftCaret
      UITextRange *range;
      if (!isSelectionMode)
        range = [tv textRangeFromPosition:position toPosition:position];
      else {
        if (startTextRange.isEmpty)
          range = [tv textRangeFromPosition:startTextRange.start toPosition:position];
        else
          range = [tv textRangeFromPosition:isLeftPanning ? startTextRange.end : startTextRange.start toPosition:position];
      }
      tv.selectedTextRange = range;
      // reveal for UITextField.
      [[%c(UIFieldEditor) sharedFieldEditor] revealSelection];

    } else {
      // for iOS 4
      int location = startRange.location;
      location += pointsChanged;
      int selectedLength = startRange.length;
      
      if (isSelectionMode) {
        if (pointsChanged < 0) {
          if (startRange.length == 0) {
            selectedLength += abs(pointsChanged);
            if (location < 0)
              selectedLength = startRange.location;
          } else {
            if (!isLeftPanning) {
              selectedLength -= abs(pointsChanged);
              if (selectedLength > 0) {
                location = startRange.location;
              } else {
                location += startRange.length; 
                selectedLength = startRange.location - location;
                if (selectedLength > startRange.location)
                  selectedLength = startRange.location;
              }
            } else {
              selectedLength += abs(pointsChanged);
              if (selectedLength > startRange.location + startRange.length)
                selectedLength = startRange.location + startRange.length;
            }
          }
        } else {
          if (startRange.length == 0) {
            selectedLength += abs(pointsChanged);
            location = startRange.location;
          } else {
            selectedLength += abs(pointsChanged);
            location = startRange.location;
          }
        }
      } else
        selectedLength = 0;

      if (location < 0)
        location = 0;
      else if (location > tv.text.length)
        location = tv.text.length;

      if (selectedLength + location > tv.text.length)
        selectedLength = tv.text.length - location;
      else if (selectedLength > tv.text.length)
        selectedLength = tv.text.length;

      NSRange range = NSMakeRange(location,selectedLength);

      if ([tv respondsToSelector:@selector(setSelectedRange:)]) {
        // UITextView and UITextContentView
        [tv setSelectedRange:range];
      } else if ([tv respondsToSelector:@selector(setSelectionRange:)]) {
        // UITextField
        [tv setSelectionRange:range];
      }
    }
  }
}
%end

static void LoadSettings()
{	
  NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
  id existPanGesture = [dict objectForKey:@"PanGestureEnabled"];
  panGestureEnabled = existPanGesture ? [existPanGesture boolValue] : YES;
  id existVelocity = [dict objectForKey:@"VelocityEnabled"];
  fasterByVelocityIsEnabled = existVelocity ? [existVelocity boolValue] : NO;
  id existCaretMagnifier = [dict objectForKey:@"CaretMagnifierEnabled"];
  caretMagnifierIsEnabled = existCaretMagnifier ? [existCaretMagnifier boolValue] : NO;
  if (tv) {
    if (panGestureEnabled)
      InstallPanGestureRecognizer();
    else
      InstallSwipeGestureRecognizer();
  }
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
