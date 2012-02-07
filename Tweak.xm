// NOTE: This tweak using property and method of UITextInput protocol.
//       Hooked classes are applied UITextInput protocol since iOS5 except UIWebDocumentView.
//       So this tweak depend iOS 5+.

#define LEFT_SWIPE_SHIFT_CARET \
  if (![tv comparePosition:tv.selectedTextRange.start toPosition:tv.beginningOfDocument] == NSOrderedSame) \
    ShiftCaret(tv, YES)

#define RIGHT_SWIPE_SHIFTCARET \
  if (![tv comparePosition:tv.selectedTextRange.end toPosition:tv.endOfDocument] == NSOrderedSame) \
    ShiftCaret(tv, NO)

@protocol DummyForUIWebDocumentViewMethod
- (unsigned short)characterBeforeCaretSelection;
- (unsigned short)characterAfterCaretSelection;
@end

static id<UITextInput, DummyForUIWebDocumentViewMethod> tv;

@interface UIWebDocumentView : UIView <UITextInput, DummyForUIWebDocumentViewMethod>
@end

@interface UITextContentView : UIView <UITextInput, DummyForUIWebDocumentViewMethod>
@end

@interface UITextField (Private) <DummyForUIWebDocumentViewMethod>
@end

@interface UITextView (Private) <DummyForUIWebDocumentViewMethod>
@end

static void InstallSwipeGestureRecognizer(id self)
{
  UISwipeGestureRecognizer *rightSwipeShiftCaret = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(rightSwipeShiftCaret:)];
  rightSwipeShiftCaret.direction = UISwipeGestureRecognizerDirectionRight;
  [self addGestureRecognizer:rightSwipeShiftCaret];
  [rightSwipeShiftCaret release];

  UISwipeGestureRecognizer *leftSwipeShiftCaret = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(leftSwipeShiftCaret:)];
  leftSwipeShiftCaret.direction = UISwipeGestureRecognizerDirectionLeft;
  [self addGestureRecognizer:leftSwipeShiftCaret];
  [leftSwipeShiftCaret release];
}

static void ShiftCaret(id<UITextInput> self, BOOL isLeftSwipe)
{
  UITextPosition *position = isLeftSwipe ? [self positionFromPosition:self.selectedTextRange.start inDirection:UITextLayoutDirectionLeft offset:1]
    : [self positionFromPosition:self.selectedTextRange.end inDirection:UITextLayoutDirectionRight offset:1];
  UITextRange *range = [self textRangeFromPosition:position toPosition:position];
  [self setSelectedTextRange:range];
}

// UIWebDocumentView
/////////////////////////////////////////////////////////////////////////////

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

%hook UIWebDocumentView
- (BOOL)becomeFirstResponder
{
  tv = self;
  InstallSwipeGestureRecognizer(self);
  return %orig;
}

// TODO: failsafe apply same with others.
//       @selector(comparePosition:toPosition:) is already implemented
//       but not return NSOrderedSame on GMail.app
%new(v@:@)
- (void)leftSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  if ([tv characterBeforeCaretSelection] != 0)
    ShiftCaret(tv, YES);
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  if ([tv characterAfterCaretSelection] != 0)
    ShiftCaret(tv, NO);
}
%end

// UITextContentView
/////////////////////////////////////////////////////////////////////////////

%hook UITextContentView
- (BOOL)becomeFirstResponder
{
  tv = self;
  InstallSwipeGestureRecognizer(self);
  return %orig;
}

%new(v@:@)
- (void)leftSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  LEFT_SWIPE_SHIFT_CARET;
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  RIGHT_SWIPE_SHIFTCARET;
}
%end

// UITextField
/////////////////////////////////////////////////////////////////////////////

%hook UITextField
- (void)_becomeFirstResponder
{
  tv = self;
  InstallSwipeGestureRecognizer(self);
  return %orig;
}

%new(v@:@)
- (void)leftSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  LEFT_SWIPE_SHIFT_CARET;
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  RIGHT_SWIPE_SHIFTCARET;
}
%end

// UITextView
/////////////////////////////////////////////////////////////////////////////

%hook UITextView
- (BOOL)becomeFirstResponder
{
  tv = self;
  InstallSwipeGestureRecognizer(self);
  return %orig;
}

%new(v@:@)
- (void)leftSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  LEFT_SWIPE_SHIFT_CARET;
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  RIGHT_SWIPE_SHIFTCARET;
}
%end
