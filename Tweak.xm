static NSMutableSet *viewSets;

@interface UIView (Private) <UITextInput>
@end

static void InstallSwipeGestureRecognizer()
{
  for (UIView *tv in [[viewSets copy] autorelease]) {
    UISwipeGestureRecognizer *rightSwipeShiftCaret = [[UISwipeGestureRecognizer alloc] initWithTarget:tv action:@selector(rightSwipeShiftCaret:)];
    rightSwipeShiftCaret.direction = UISwipeGestureRecognizerDirectionRight;
    [tv addGestureRecognizer:rightSwipeShiftCaret];
    [rightSwipeShiftCaret release];

    UISwipeGestureRecognizer *leftSwipeShiftCaret = [[UISwipeGestureRecognizer alloc] initWithTarget:tv action:@selector(leftSwipeShiftCaret:)];
    leftSwipeShiftCaret.direction = UISwipeGestureRecognizerDirectionLeft;
    [tv addGestureRecognizer:leftSwipeShiftCaret];
    [leftSwipeShiftCaret release];
  }
}

static void ShiftCaret(BOOL isLeftSwipe)
{
  for (UIView *tv in [[viewSets copy] autorelease]) {
    UITextPosition *position = isLeftSwipe ? [tv positionFromPosition:tv.selectedTextRange.start inDirection:UITextLayoutDirectionLeft offset:1]
      : [tv positionFromPosition:tv.selectedTextRange.end inDirection:UITextLayoutDirectionRight offset:1];
    // failsafe for over edge position crash.
    if (!position)
      continue;
    UITextRange *range = [tv textRangeFromPosition:position toPosition:position];
    [tv setSelectedTextRange:range];
  }
}

%hook UIView
- (BOOL)becomeFirstResponder
{
  if ([self respondsToSelector:@selector(setSelectedTextRange:)]) {
    [viewSets addObject:self];
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
