// NOTE: This tweak using property and method of UITextInput protocol.
//       Hooked classes are applied UITextInput protocol since iOS5 except UIWebDocumentView.
//       So this tweak depend iOS 5+.

static UIResponder <UITextInput> *tv;

@interface UIResponder (Private) <UITextInput>
- (unsigned long)_characterBeforeCaretSelection;
- (unsigned long)_characterAfterCaretSelection;
- (unsigned short)characterBeforeCaretSelection;
- (unsigned short)characterAfterCaretSelection;
- (void)addGestureRecognizer:(UIGestureRecognizer *)gesture;
- (BOOL)_isEmptySelection;
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
  // NOTE: If selected state, _character*CaretSelection return 0.
  //       this opinion is to move caret from selected state.
  if ([tv _isEmptySelection]) {
    if ([tv _characterBeforeCaretSelection] == 0)
      return;
  } else {
    if ([tv comparePosition:tv.selectedTextRange.start toPosition:tv.beginningOfDocument] == NSOrderedSame)
      return;
    // NOTE: failsafe for UIWebDocumentView
    if ([tv respondsToSelector:@selector(characterBeforeCaretSelection)])
      if ([tv characterBeforeCaretSelection] == 0)
        return;
  }
  ShiftCaret(YES);
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  if ([tv _isEmptySelection]) {
    if ([tv _characterAfterCaretSelection] == 0)
      return;
  } else {
    if ([tv comparePosition:tv.selectedTextRange.end toPosition:tv.endOfDocument] == NSOrderedSame)
      return;
    if ([tv respondsToSelector:@selector(characterAfterCaretSelection)])
      if ([tv characterAfterCaretSelection] == 0)
        return;
  }
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
