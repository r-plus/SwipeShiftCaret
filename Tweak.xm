static UIView *tv;
static BOOL keyboardIsAppearing = NO;
static BOOL observerRegistered = NO;

@interface UIView (Private) <UITextInput>
@end

static void InstallSwipeGestureRecognizer()
{
  UISwipeGestureRecognizer *rightSwipeShiftCaret = [[UISwipeGestureRecognizer alloc] initWithTarget:tv action:@selector(rightSwipeShiftCaret:)];
  rightSwipeShiftCaret.direction = UISwipeGestureRecognizerDirectionRight;
  [tv addGestureRecognizer:rightSwipeShiftCaret];
  [rightSwipeShiftCaret release];

  UISwipeGestureRecognizer *leftSwipeShiftCaret = [[UISwipeGestureRecognizer alloc] initWithTarget:tv action:@selector(leftSwipeShiftCaret:)];
  leftSwipeShiftCaret.direction = UISwipeGestureRecognizerDirectionLeft;
  [tv addGestureRecognizer:leftSwipeShiftCaret];
  [leftSwipeShiftCaret release];
}

static void ShiftCaret(BOOL isLeftSwipe)
{
  UITextPosition *position = isLeftSwipe ? [tv positionFromPosition:tv.selectedTextRange.start inDirection:UITextLayoutDirectionLeft offset:1]
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
  if ([self respondsToSelector:@selector(setSelectedTextRange:)]) {
    tv = self;
    if (keyboardIsAppearing)
      InstallSwipeGestureRecognizer();

    if (!observerRegistered) {
      NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
      [center addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
      [center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
      observerRegistered = YES;
    }
  }
  return %orig;
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

%new(v@:@)
- (void)keyboardWillShow:(NSNotification *)notification
{
  keyboardIsAppearing = YES;
  InstallSwipeGestureRecognizer();
}

%new(v@:@)
- (void)keyboardWillHide:(NSNotification *)notification
{
  keyboardIsAppearing = NO;

  if (observerRegistered && ![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.google.Gmail"]) {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [center removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    observerRegistered = NO;
  }

  for (UISwipeGestureRecognizer *gesture in [tv gestureRecognizers]) {
    if ([gesture isMemberOfClass:[UISwipeGestureRecognizer class]]) {
      NSArray *targets = MSHookIvar<NSArray *>(gesture, "_targets");
      SEL action = MSHookIvar<SEL>([targets objectAtIndex:0], "_action");
      if (@selector(leftSwipeShiftCaret:) == action || @selector(rightSwipeShiftCaret:) == action)
        [tv removeGestureRecognizer:gesture];
    }
  }
}
%end
