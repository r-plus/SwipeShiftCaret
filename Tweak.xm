static UIView *tv;

@interface UIView (Private) <UITextInput>
@end

@interface SCSwipeGestureRecognizer : UISwipeGestureRecognizer
@end

@implementation SCSwipeGestureRecognizer
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer {
  return NO;
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer {
  return NO;
}
@end

static void InstallSwipeGestureRecognizer()
{
  SCSwipeGestureRecognizer *rightSwipeShiftCaret = [[SCSwipeGestureRecognizer alloc] initWithTarget:tv action:@selector(rightSwipeShiftCaret:)];
  rightSwipeShiftCaret.direction = UISwipeGestureRecognizerDirectionRight;
  [tv addGestureRecognizer:rightSwipeShiftCaret];
  [rightSwipeShiftCaret release];

  SCSwipeGestureRecognizer *leftSwipeShiftCaret = [[SCSwipeGestureRecognizer alloc] initWithTarget:tv action:@selector(leftSwipeShiftCaret:)];
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
    InstallSwipeGestureRecognizer();
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
%end
