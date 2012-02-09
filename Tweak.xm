// NOTE: This tweak using property and method of UITextInput protocol.
//       Hooked classes are applied UITextInput protocol since iOS5 except UIWebDocumentView.
//       So this tweak depend iOS 5+.

static UIResponder *tv;

@interface UIResponder (Private) <UITextInput>
- (unsigned long)_characterBeforeCaretSelection;
- (unsigned long)_characterAfterCaretSelection;
- (void)addGestureRecognizer:(UIGestureRecognizer *)gesture;
@end

@interface BrowserController : NSObject
- (UIWebDocumentView *)activeWebView;
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
  UITextRange *range = [tv textRangeFromPosition:position toPosition:position];
  [tv setSelectedTextRange:range];
}

%hook UIResponder
- (BOOL)becomeFirstResponder
{
  if ([self respondsToSelector:@selector(setSelectedTextRange:)]) {
    tv = self;
    InstallSwipeGestureRecognizer();
  }
  return %orig;
}

%new(v@:)
- (void)leftSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  if ([tv _characterBeforeCaretSelection] != 0)
    ShiftCaret(YES);
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  if ([tv _characterAfterCaretSelection] != 0)
    ShiftCaret(NO);
}
%end

// NOTE: special handling for MobileSafari + Sleipnizer's L/R Gestures.
%hook BrowserController
-(void)_keyboardWillHide:(id)_keyboard
{
  %orig;

  for (UISwipeGestureRecognizer *gesture in [[self activeWebView] gestureRecognizers]) {
    if ([gesture isMemberOfClass:[UISwipeGestureRecognizer class]]) {
      NSArray *targets = MSHookIvar<NSArray *>(gesture, "_targets");
      SEL action = MSHookIvar<SEL>([targets objectAtIndex:0], "_action");
      if (@selector(leftSwipeShiftCaret:) == action || @selector(rightSwipeShiftCaret:) == action)
        [[self activeWebView] removeGestureRecognizer:gesture];
    }
  }
}
%end
