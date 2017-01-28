#import <ColorLog.h>
#import <Firmware.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

#define PREF_PATH @"/var/mobile/Library/Preferences/jp.r-plus.SwipeShiftCaret.plist"

// interfaces {{{
@interface WKContentView
- (NSString *)selectedText;
- (void)_moveRight:(BOOL)extend withHistory:(id)history;
- (void)_moveLeft:(BOOL)extend withHistory:(id)history;
- (void)selectWordBackward;
- (void)executeEditCommandWithCallback:(NSString *)commandName;
@end

@interface UIWebDocumentView : UIView <UITextInput>
- (BOOL)isEditing;
- (void)beginSelectionChange;
- (void)endSelectionChange;
@end

@interface UIView (Private) <UITextInput>
- (UIWebDocumentView *)webView;
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

@protocol UITextInputPrivate <UITextInput, UITextInputTokenizer>
@end

@interface TIKeyboardState : NSObject
@property(copy, nonatomic) NSString *searchStringForMarkedText;
@property(copy, nonatomic) NSString *inputForMarkedText;
@end

@interface UIKeyboardImpl : NSObject
+ (id)sharedInstance;
- (BOOL)callLayoutIsShiftKeyBeingHeld;
- (BOOL)caretVisible;
@property (readonly, assign, nonatomic) UIResponder <UITextInputPrivate> *privateInputDelegate;
@property (readonly, assign, nonatomic) UIResponder <UITextInput> *inputDelegate;
- (id)searchStringForMarkedText;
- (BOOL)hasEditableMarkedText;
- (BOOL)hasMarkedText;
- (void)generateCandidates;
// iOS 7+
- (id)markedText;
- (void)setMarkedText:(id)arg1 selectedRange:(NSRange)arg2 inputString:(id)arg3 searchString:(id)arg4;
@end

@interface UIFieldEditor : NSObject
+ (id)sharedFieldEditor;
- (void)revealSelection; // iOS ~9
- (void)scrollSelectionToVisible:(BOOL)arg1; // iOS 4+
@end

@interface UIKeyboardLayoutStar : NSObject
- (UIKBKey *)keyHitTest:(CGPoint)arg;
- (NSString *)displayString;
@end

@interface UITextMagnifierRanged
@property (retain) UIView *target;
+ (id)sharedRangedMagnifier;
@end
// }}}

// global variables {{{
static UIView *tv;
static UIWebDocumentView *webView;
static BOOL panGestureEnabled;
static BOOL fasterByVelocityIsEnabled;
static BOOL verticalScrollLockIsEnabled;
static BOOL verticalScrollLockAndMoveIsEnabled;
static BOOL isSelectionMode = NO;
static BOOL hasStarted = NO;
static BOOL isPreventSwipeLoupe;
// }}}

// GestureRecognizers {{{
@interface SCSwipeGestureRecognizer : UISwipeGestureRecognizer
@end

@implementation SCSwipeGestureRecognizer
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)gesture
{
    if ([gesture isMemberOfClass:[SCSwipeGestureRecognizer class]])
        return YES;
    return NO;
}

// NOTE: This method didnot call for UISwipeGestureRecognizer if UIDragRecognizer is dragable since iOS 7+.
- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)gesture
{
    // Prevent duplicated myself
    if ([gesture isMemberOfClass:[SCSwipeGestureRecognizer class]])
        return YES;
    // Don't prevent SwipeNav
    if ([gesture isMemberOfClass:%c(SNSwipeGestureRecognizer)])
        return NO;
    return NO;
}
@end

@interface SCPanGestureRecognizer : UIPanGestureRecognizer
@end

@implementation SCPanGestureRecognizer
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)gesture
{
    if ([gesture isMemberOfClass:[SCPanGestureRecognizer class]])
        return YES;
    return NO;
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)gesture
{
    CMLog(@"%@", gesture);
    // Prevent duplicated myself
    if ([gesture isMemberOfClass:[SCPanGestureRecognizer class]])
        return YES;
    // Don't prevent SwipeNav
    if ([gesture isMemberOfClass:%c(SNSwipeGestureRecognizer)])
        return NO;
    // v.scroll lock option
    if (hasStarted && [gesture isKindOfClass:[UIPanGestureRecognizer class]])
        if (verticalScrollLockIsEnabled || verticalScrollLockAndMoveIsEnabled)
            return YES;
    // UIDragRecognizer action @selector(loupeGesture:) since iOS 7+
    // But caret shift performance is too bad even if prevent this gestureRecognizer.
/*    if (isPreventSwipeLoupe && [gesture isKindOfClass:%c(UIDragRecognizer)])*/
/*        return YES;*/
    return NO;
}
@end

// }}}

// functions {{{
static void InstallSwipeGestureRecognizer()
{
    // if this uninstall pan gesture is nothing, should implement 'if (panGestureEnabled) return;' code
    // top of ShiftCaret function.
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

static void UpdateCaretAndCandidateIfNecessary(UITextRange *range)
{
    UITextRange *markedTextRange = nil;
    if ([webView respondsToSelector:@selector(markedTextRange)])
        markedTextRange = webView.markedTextRange;
    // return target(firstresponder) view if showing magnifier view to zoom IME converting strings.
    if (markedTextRange && [[%c(UITextMagnifierRanged) sharedRangedMagnifier] target])
        return;
    UIKeyboardImpl *keyboardImpl = [%c(UIKeyboardImpl) sharedInstance];
    // if nou supported update markedtext, only update caret position.
    if (!markedTextRange || isSelectionMode || kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0) {
        webView.selectedTextRange = range;
        return;
    }
    TIKeyboardState *m_keyboardState = (TIKeyboardState *)[keyboardImpl valueForKey:@"m_keyboardState"];

    // markedText edge over check.
    NSComparisonResult result;
    result = [webView comparePosition:range.start toPosition:markedTextRange.start];
    if (result == NSOrderedAscending)
        range = [webView textRangeFromPosition:markedTextRange.start toPosition:markedTextRange.start];
    result = [webView comparePosition:range.end toPosition:markedTextRange.end];
    if (result == NSOrderedDescending)
        range = [webView textRangeFromPosition:markedTextRange.end toPosition:markedTextRange.end];

    UITextPosition *beginning = webView.beginningOfDocument;
    NSUInteger offsetToTargetPosition = [webView offsetFromPosition:beginning toPosition:range.start];
    NSUInteger offsetToMarkedTextPosition = [webView offsetFromPosition:beginning toPosition:markedTextRange.start];

    [keyboardImpl setMarkedText:[keyboardImpl markedText]
                  selectedRange:NSMakeRange(offsetToTargetPosition-offsetToMarkedTextPosition, 0)
                    inputString:[m_keyboardState inputForMarkedText]
                   searchString:[keyboardImpl searchStringForMarkedText]];
    [keyboardImpl generateCandidates];
}

static void ShiftCaretToLeft(BOOL isLeftSwipe)
{
    if ([webView isKindOfClass:%c(WKContentView)]) {
        // iOS 8+ WebKit.framework base view.
        if (isLeftSwipe)
            [(WKContentView *)webView _moveLeft:NO withHistory:nil];
        else
            [(WKContentView *)webView _moveRight:NO withHistory:nil];
    } else if ([webView respondsToSelector:@selector(positionFromPosition:inDirection:offset:)]) {
        UITextPosition *position = nil;
        position = isLeftSwipe ? [webView positionFromPosition:webView.selectedTextRange.start inDirection:UITextLayoutDirectionLeft offset:1]
            : [webView positionFromPosition:webView.selectedTextRange.end inDirection:UITextLayoutDirectionRight offset:1];
        // failsafe for over edge position crash.
        if (!position)
            return;
        UITextRange *range = [webView textRangeFromPosition:position toPosition:position];
        [webView beginSelectionChange];
        UpdateCaretAndCandidateIfNecessary(range);
        [webView endSelectionChange];
    }

    // reveal for UITextField iOS ~9.
    UIFieldEditor *editor = [%c(UIFieldEditor) sharedFieldEditor];
    if ([editor respondsToSelector:@selector(revealSelection)]) {
        [editor revealSelection];
    } else {
        [editor scrollSelectionToVisible:YES];
    }
    // reveal for UITextView, UITextContentView and UIWebDocumentView.
    if ([tv respondsToSelector:@selector(scrollSelectionToVisible:)])
        [tv scrollSelectionToVisible:YES];
}

static void PopupMenuFromRect(CGRect rect)
{
    UIMenuController *mc = [UIMenuController sharedMenuController];
    [mc setTargetRect:rect inView:tv];
    [mc setMenuVisible:YES animated:YES];
}
// }}}

// Hooks {{{
%hook UIKeyboardLayoutStar
static BOOL IsForSelectionModeString(NSString * string)
{
    return ([string isEqualToString:@"あいう"] ||
            [string isEqualToString:@"ABC"] ||
            [string isEqualToString:@"☆123"] ||
            [string isEqualToString:@"123"]
           );
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    %orig;
    UITouch *touch = [touches anyObject];
    UIKBKey *kb = [self keyHitTest:[touch locationInView:touch.view]];
    NSString *kbString = [kb displayString];
    if ([webView respondsToSelector:@selector(markedTextRange)]) {
        isSelectionMode = (!webView.markedTextRange && IsForSelectionModeString(kbString));
    } else {
        isSelectionMode = IsForSelectionModeString(kbString);
    }
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

%group iOS_ge_70_lt_90
%hook UIDragRecognizer
- (BOOL)canBeginDrag
{
    return isPreventSwipeLoupe ? NO : %orig;
}
%end
%end

%hook UIView
- (BOOL)becomeFirstResponder
{
    BOOL tmp = %orig;
    if (tmp && ([self respondsToSelector:@selector(setSelectedTextRange:)] ||
                [self respondsToSelector:@selector(setSelectedRange:)] ||
                [self respondsToSelector:@selector(setSelectionRange:)])) {
        if ([self isKindOfClass:%c(UIWebDocumentView)]) {
            tv = webView = (UIWebDocumentView *)self;
        } else {
            tv = self;
            // iOS 7: webView method no longer supported, its returning nil.
            if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0)
                webView = (UIWebDocumentView *)tv;
            else if ([self respondsToSelector:@selector(webView)])
                webView = [tv webView];
        }
        CMLog(@"firstResponder class = %@", NSStringFromClass([self class]));
        CMLog(@"tv = %@, webView = %@", tv, webView);
        if (panGestureEnabled)
            InstallPanGestureRecognizer();
        else
            InstallSwipeGestureRecognizer();
        CMLog(@"gestureRecognizers = %@", [self gestureRecognizers]);
    }
    return tmp;
}

- (BOOL)resignFirstResponder
{
    if (tv == self) {
        tv = nil;
        webView = nil;
    }
    return %orig;
}

%new
- (void)leftSwipeShiftCaret:(UISwipeGestureRecognizer *)gesture
{
    ShiftCaretToLeft(YES);
}

%new
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)gesture
{
    ShiftCaretToLeft(NO);
}

// based code is SwipeSelection.
%new
- (void)SCPanGestureDidPan:(UIPanGestureRecognizer *)gesture
{
    if (!panGestureEnabled)
        return;

    static BOOL isLeftPanning = YES;
    static BOOL beginningRangeIsEmpty;
    static UITextPosition *beginningStartPosition;
    static UITextPosition *beginningEndPosition;
    static int numberOfTouches = 0;
    static CGPoint previousVelocityPoint;
    static int previousXOffset = 0;
    static int previousYOffset = 0;

    int touchesCount = [gesture numberOfTouches];
    if (touchesCount > numberOfTouches)
        numberOfTouches = touchesCount;

    UIKeyboardImpl *keyboardImpl = [%c(UIKeyboardImpl) sharedInstance];
    // fix for un-editable UIWebDocumentView.
    // NOTE: -(BOOL)isEditing method of UIWebDocumentView always return NO, it's not useful.
    if (![keyboardImpl caretVisible])
        return;

    if ([keyboardImpl respondsToSelector:@selector(callLayoutIsShiftKeyBeingHeld)] && !isSelectionMode)
        isSelectionMode = [keyboardImpl callLayoutIsShiftKeyBeingHeld];

    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        // cleanup
        numberOfTouches = 0;
        previousVelocityPoint = CGPointMake(0,0);
        isLeftPanning = YES;
        gesture.cancelsTouchesInView = NO;
        if (beginningStartPosition)
            [beginningStartPosition release];
        beginningStartPosition = nil;
        if (beginningEndPosition)
            [beginningEndPosition release];
        beginningEndPosition = nil;
        previousXOffset = 0;
        previousYOffset = 0;

        // reveal for UITextView, UITextContentView and UIWebDocumentView.
        if ([tv respondsToSelector:@selector(scrollSelectionToVisible:)] && hasStarted)
            [tv scrollSelectionToVisible:YES];
        hasStarted = NO;

        // auto pop-up menu.
        if ([webView respondsToSelector:@selector(selectedTextRange)]) {
            UITextRange *range = webView.selectedTextRange;
            if (range && !range.isEmpty)
                PopupMenuFromRect([webView firstRectForRange:range]);
        }
        
        // fix text deletion issue during Korean syllable composing
        [webView endSelectionChange];

    } else if (gesture.state == UIGestureRecognizerStateBegan) {

        beginningStartPosition = [webView.selectedTextRange.start retain];
        beginningEndPosition = [webView.selectedTextRange.end retain];
        beginningRangeIsEmpty = [webView comparePosition:beginningStartPosition toPosition:beginningEndPosition] == NSOrderedSame;
        
        // fix text deletion issue during Korean syllable composing
        [webView beginSelectionChange];

    } else if (gesture.state == UIGestureRecognizerStateChanged) {

        CGPoint offset = [gesture translationInView:tv];
        if (!hasStarted && fabs(offset.x) < 16.0)
            return;
        if (!hasStarted && fabs(offset.x) < fabs(offset.y)) {
            gesture.state = UIGestureRecognizerStateEnded;
            return;
        }
        if (!hasStarted)
            isLeftPanning = offset.x < 0 ? YES : NO;
        gesture.cancelsTouchesInView = YES;
        hasStarted = YES;
        if (fasterByVelocityIsEnabled) {
            CGPoint velo = [gesture velocityInView:tv];
            if (fabs(previousVelocityPoint.x) < 1000.0 && fabs(velo.x) / 1000.0 != 0)
                numberOfTouches += (fabs(velo.x) / 1000.0);
            previousVelocityPoint = velo;
        }
        int scale = 16 / numberOfTouches ? : 1;
        int xPointsChanged = offset.x / scale;
        int yPointsChanged = offset.y / scale;

        if ([webView isKindOfClass:%c(WKContentView)]) {
            // WebKit based view.

            // Horizontal Move.
            if (xPointsChanged == previousXOffset) {
                // do nothing.
            } else if (xPointsChanged > previousXOffset) {
                // isRightSwipe:
                for(; xPointsChanged > previousXOffset; previousXOffset++) {
                    [(WKContentView *)webView executeEditCommandWithCallback:isSelectionMode ? @"moveRightAndModifySelection" : @"moveRight"];
                }
            } else {
                // isLeftSwipe:
                for(; xPointsChanged < previousXOffset; previousXOffset--) {
                    [(WKContentView *)webView executeEditCommandWithCallback:isSelectionMode ? @"moveLeftAndModifySelection" : @"moveLeft"];
                }
            }

            // Vertical Move.
            if (verticalScrollLockAndMoveIsEnabled) {
                if (yPointsChanged == previousYOffset) {
                    // do nothing.
                } else if (yPointsChanged > previousYOffset) {
                    // isDownSwipe:
                    for(; yPointsChanged > previousYOffset; previousYOffset++) {
                        [(WKContentView *)webView executeEditCommandWithCallback:isSelectionMode ? @"moveDownAndModifySelection" : @"moveDown"];
                    }
                } else {
                    // isUpSwipe:
                    for(; yPointsChanged < previousYOffset; previousYOffset--) {
                        [(WKContentView *)webView executeEditCommandWithCallback:isSelectionMode ? @"moveUpAndModifySelection" : @"moveUp"];
                    }
                }
            }

            // No need manually reveal, automatically reveal via framework.

        } else if ([webView respondsToSelector:@selector(positionFromPosition:inDirection:offset:)]) {
            // UIKit based view.
            UITextPosition *position = nil;
            // Horizontal Move.
            if (beginningRangeIsEmpty) {
                position = [webView positionFromPosition:beginningStartPosition
                    inDirection:xPointsChanged < 0 ? UITextLayoutDirectionLeft : UITextLayoutDirectionRight
                    offset:abs(xPointsChanged)];
            } else {
                position = [webView positionFromPosition:isLeftPanning ? beginningStartPosition : beginningEndPosition
                    inDirection:xPointsChanged < 0 ? UITextLayoutDirectionLeft : UITextLayoutDirectionRight
                    offset:abs(xPointsChanged)];
            }
            // Vertical Move.
            if (verticalScrollLockAndMoveIsEnabled) {
                position = [webView positionFromPosition:position
                    inDirection:yPointsChanged < 0 ? UITextLayoutDirectionUp : UITextLayoutDirectionDown
                    offset:abs(yPointsChanged)];
            }
            // over edge correction.
            if (!position) {
                position = xPointsChanged < 0 ? webView.beginningOfDocument : webView.endOfDocument;
            }

            // ShiftCaret
            UITextRange *range;
            if (!isSelectionMode) {
                range = [webView textRangeFromPosition:position toPosition:position];
            } else {
                if (beginningRangeIsEmpty)
                    range = [webView textRangeFromPosition:beginningStartPosition toPosition:position];
                else
                    range = [webView textRangeFromPosition:isLeftPanning ? beginningEndPosition : beginningStartPosition toPosition:position];
            }
            UpdateCaretAndCandidateIfNecessary(range);
            // reveal for UITextField.
            UIFieldEditor *editor = [%c(UIFieldEditor) sharedFieldEditor];
            if ([editor respondsToSelector:@selector(revealSelection)]) {
                // iOS ~9
                [editor revealSelection];
            } else {
                [editor scrollSelectionToVisible:YES];
            }
        }
    }
}
%end
// }}}

static void LoadSettings()
{
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    id panGesturePref = [dict objectForKey:@"PanGestureEnabled"];
    panGestureEnabled = panGesturePref ? [panGesturePref boolValue] : YES;
    id velocityPref = [dict objectForKey:@"VelocityEnabled"];
    fasterByVelocityIsEnabled = velocityPref ? [velocityPref boolValue] : NO;
    id verticalScrollLockPref = [dict objectForKey:@"LockVerticalScrollEnabled"];
    verticalScrollLockIsEnabled = verticalScrollLockPref ? [verticalScrollLockPref boolValue] : NO;
    id verticalScrollLockAndMovePref = [dict objectForKey:@"VLockAndMoveEnabled"];
    verticalScrollLockAndMoveIsEnabled = verticalScrollLockAndMovePref ? [verticalScrollLockAndMovePref boolValue] : NO;
    id preventSwipeLoupePref = [dict objectForKey:@"PreventSwipeLoupe"];
    isPreventSwipeLoupe = preventSwipeLoupePref ? [preventSwipeLoupePref boolValue] : YES;
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
    @autoreleasepool {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PostNotification, CFSTR("jp.r-plus.swipeshiftcaret.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
        LoadSettings();
        %init;
        if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0 && kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_9_0)
            %init(iOS_ge_70_lt_90);
    }
}

/* vim: set fdm=marker : */
