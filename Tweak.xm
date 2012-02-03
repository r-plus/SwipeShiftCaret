// NOTE: This tweak using property and method of UITextInput protocol.
//       Hooked classes are applied UITextInput protocol since iOS5 except UIWebDocumentView.
//       So this tweak depend iOS 5+.

@interface UIWebDocumentView : UIView <UITextInput>
- (unsigned short)characterBeforeCaretSelection;
- (unsigned short)characterAfterCaretSelection;
@end

@interface UITextContentView : UIView <UITextInput>
- (void)setSelectedRange:(NSRange)range;
@end

@interface UITextField (Private)
- (void)setSelectionRange:(NSRange)range;
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

static UIWebDocumentView *webDocumentView;
%hook UIWebDocumentView
- (BOOL)becomeFirstResponder
{
  webDocumentView = self;
  InstallSwipeGestureRecognizer(self);
  return %orig;
}

%new(v@:@)
- (void)leftSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  if ([webDocumentView characterBeforeCaretSelection] != 0)
    ShiftCaret(webDocumentView, YES);
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  if ([webDocumentView characterAfterCaretSelection] != 0)
    ShiftCaret(webDocumentView, NO);
}
%end

// UITextContentView
/////////////////////////////////////////////////////////////////////////////

static UITextContentView *contentView;
%hook UITextContentView
- (BOOL)becomeFirstResponder
{
  contentView = self;
  InstallSwipeGestureRecognizer(self);
  return %orig;
}

%new(v@:@)
- (void)leftSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  if (![contentView comparePosition:contentView.selectedTextRange.start toPosition:contentView.beginningOfDocument] == NSOrderedSame)
    ShiftCaret(contentView, YES);
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  if (![contentView comparePosition:contentView.selectedTextRange.end toPosition:contentView.endOfDocument] == NSOrderedSame)
    ShiftCaret(contentView, NO);
}
%end

// UITextField
/////////////////////////////////////////////////////////////////////////////

static UITextField *textField;
%hook UITextField
- (void)_becomeFirstResponder
{
  %orig;
  textField = self;
  InstallSwipeGestureRecognizer(self);
}

%new(v@:@)
- (void)leftSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  if (![textField comparePosition:textField.selectedTextRange.start toPosition:textField.beginningOfDocument] == NSOrderedSame)
    ShiftCaret(textField, YES);
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  if (![textField comparePosition:textField.selectedTextRange.end toPosition:textField.endOfDocument] == NSOrderedSame)
    ShiftCaret(textField, NO);
}
%end

// UITextView
/////////////////////////////////////////////////////////////////////////////

static UITextView *textView;
%hook UITextView
- (BOOL)becomeFirstResponder
{
  textView = self;
  InstallSwipeGestureRecognizer(self);
  return %orig;
}

%new(v@:@)
- (void)leftSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  if (![textView comparePosition:textView.selectedTextRange.start toPosition:textView.beginningOfDocument] == NSOrderedSame)
    ShiftCaret(textView, YES);
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  if (![textView comparePosition:textView.selectedTextRange.end toPosition:textView.endOfDocument] == NSOrderedSame)
    ShiftCaret(textView, NO);
}
%end
