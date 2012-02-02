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

static inline void InstallSwipeGestureRecognizer(id self)
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

static NSUInteger OffsetFromBeginningOfDocument(id<UITextInput> view, BOOL isLeftSwipe)
{
  UITextPosition *start = view.selectedTextRange.start;
  UITextPosition *end = view.selectedTextRange.end;
  if (isLeftSwipe)
    return [view offsetFromPosition:view.beginningOfDocument toPosition:start];
  else
    return [view offsetFromPosition:view.beginningOfDocument toPosition:end];
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
  if ([webDocumentView characterBeforeCaretSelection] == 0)
    return;
  UITextPosition *leftShitedPosition = [webDocumentView positionFromPosition:webDocumentView.selectedTextRange.start inDirection:UITextLayoutDirectionLeft offset:1];
  UITextRange *range = [webDocumentView textRangeFromPosition:leftShitedPosition toPosition:leftShitedPosition];
  [webDocumentView setSelectedTextRange:range];
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  if ([webDocumentView characterAfterCaretSelection] == 0)
    return;
  UITextPosition *rightShiftedPosition = [webDocumentView positionFromPosition:webDocumentView.selectedTextRange.end inDirection:UITextLayoutDirectionRight offset:1];
  UITextRange *range = [webDocumentView textRangeFromPosition:rightShiftedPosition toPosition:rightShiftedPosition];
  [webDocumentView setSelectedTextRange:range];
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
  NSUInteger offset = OffsetFromBeginningOfDocument(contentView, YES);
  if ([contentView comparePosition:contentView.selectedTextRange.start toPosition:contentView.beginningOfDocument] == NSOrderedSame)
    return;
  [contentView setSelectedRange:NSMakeRange(--offset,0)];
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  NSUInteger offset = OffsetFromBeginningOfDocument(contentView, NO);
  if ([contentView comparePosition:contentView.selectedTextRange.end toPosition:contentView.endOfDocument] == NSOrderedSame)
    return;
  [contentView setSelectedRange:NSMakeRange(++offset,0)];
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
  NSUInteger offset = OffsetFromBeginningOfDocument(textField, YES);
  if ([textField comparePosition:textField.selectedTextRange.start toPosition:textField.beginningOfDocument] == NSOrderedSame)
    return;
  [textField setSelectionRange:NSMakeRange(--offset,0)];
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  NSUInteger offset = OffsetFromBeginningOfDocument(textField, NO);
  if ([textField comparePosition:textField.selectedTextRange.end toPosition:textField.endOfDocument] == NSOrderedSame)
    return;
  [textField setSelectionRange:NSMakeRange(++offset,0)];
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
  NSUInteger offset = OffsetFromBeginningOfDocument(textView, YES);
  if ([textView comparePosition:textView.selectedTextRange.start toPosition:textView.beginningOfDocument] == NSOrderedSame)
    return;
  [textView setSelectedRange:NSMakeRange(--offset,0)];
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)sender
{
  NSUInteger offset = OffsetFromBeginningOfDocument(textView, NO);
  if ([textView comparePosition:textView.selectedTextRange.end toPosition:textView.endOfDocument] == NSOrderedSame)
    return;
  [textView setSelectedRange:NSMakeRange(++offset,0)];
}
%end
