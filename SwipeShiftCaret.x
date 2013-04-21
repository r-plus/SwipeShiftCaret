#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

%config(generator=internal);

#define PREF_PATH @"/var/mobile/Library/Preferences/jp.r-plus.SwipeShiftCaret.plist"

static UIView *tv;
static UIWebDocumentView *webView;
static BOOL panGestureEnabled;
static BOOL fasterByVelocityIsEnabled;
static BOOL verticalScrollLockIsEnabled;
static BOOL verticalScrollLockAnsMoveIsEnabled;
static BOOL isSelectionMode = NO;
static BOOL hasStarted = NO;

@interface UIWebDocumentView : UIView <UITextInput>
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

@interface SCSwipeGestureRecognizer : UISwipeGestureRecognizer
@end

@implementation SCSwipeGestureRecognizer
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)gesture
{
    if ([gesture isKindOfClass:[UIPanGestureRecognizer class]] &&
            ![gesture.view isKindOfClass:%c(CKMessageEntryView)] &&
            ![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.google.Gmail"])
        self.state = UIGestureRecognizerStateFailed;
    if ([gesture isMemberOfClass:[SCSwipeGestureRecognizer class]])
        return YES;
    return NO;
}

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
    if ([gesture isKindOfClass:[UIPanGestureRecognizer class]] &&
            ![gesture.view isKindOfClass:%c(CKMessageEntryView)] &&
            ![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.google.Gmail"])
        self.state = UIGestureRecognizerStateCancelled;
    if ([gesture isMemberOfClass:[SCPanGestureRecognizer class]])
        return YES;
    return NO;
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)gesture
{
    // Prevent duplicated myself
    if ([gesture isMemberOfClass:[SCPanGestureRecognizer class]])
        return YES;
    // Don't prevent SwipeNav
    if ([gesture isMemberOfClass:%c(SNSwipeGestureRecognizer)])
        return NO;
    // v.scroll lock option
    if (hasStarted && [gesture isKindOfClass:[UIPanGestureRecognizer class]])
        if (verticalScrollLockIsEnabled || verticalScrollLockAnsMoveIsEnabled)
            return YES;
    return NO;
}
@end

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

static void ShiftCaretToLeft(BOOL isLeftSwipe)
{
    if ([webView respondsToSelector:@selector(positionFromPosition:inDirection:offset:)]) {
        UITextPosition *position = nil;
        position = isLeftSwipe ? [webView positionFromPosition:webView.selectedTextRange.start inDirection:UITextLayoutDirectionLeft offset:1]
            : [webView positionFromPosition:webView.selectedTextRange.end inDirection:UITextLayoutDirectionRight offset:1];
        // failsafe for over edge position crash.
        if (!position)
            return;
        UITextRange *range = [webView textRangeFromPosition:position toPosition:position];
        webView.selectedTextRange = range;
    }

    // reveal for UITextField.
    [[%c(UIFieldEditor) sharedFieldEditor] revealSelection];
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
        if ([self isKindOfClass:%c(UIWebDocumentView)]) {
            tv = webView = (UIWebDocumentView *)self;
        } else if ([self respondsToSelector:@selector(webView)]) {
            tv = self;
            webView = [tv webView];
        }
        if (panGestureEnabled)
            InstallPanGestureRecognizer();
        else
            InstallSwipeGestureRecognizer();
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

%new(v@:@)
- (void)leftSwipeShiftCaret:(UISwipeGestureRecognizer *)gesture
{
    ShiftCaretToLeft(YES);
}

%new(v@:@)
- (void)rightSwipeShiftCaret:(UISwipeGestureRecognizer *)gesture
{
    ShiftCaretToLeft(NO);
}

// based code is SwipeSelection.
%new(v@:@)
- (void)SCPanGestureDidPan:(UIPanGestureRecognizer *)gesture
{
    if (!panGestureEnabled)
        return;

    static BOOL isLeftPanning = YES;
    static UITextRange *beginningTextRange;
    static int numberOfTouches = 0;
    static CGPoint previousVelocityPoint;

    int touchesCount = [gesture numberOfTouches];
    if (touchesCount > numberOfTouches)
        numberOfTouches = touchesCount;

    UIKeyboardImpl *keyboardImpl = [%c(UIKeyboardImpl) sharedInstance];
    if ([keyboardImpl respondsToSelector:@selector(callLayoutIsShiftKeyBeingHeld)] && !isSelectionMode)
        isSelectionMode = [keyboardImpl callLayoutIsShiftKeyBeingHeld];

    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        // cleanup
        numberOfTouches = 0;
        previousVelocityPoint = CGPointMake(0,0);
        isLeftPanning = YES;
        gesture.cancelsTouchesInView = NO;
        if (beginningTextRange)
            [beginningTextRange release];
        beginningTextRange = nil;

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

    } else if (gesture.state == UIGestureRecognizerStateBegan) {

        if ([webView respondsToSelector:@selector(positionFromPosition:inDirection:offset:)])
            beginningTextRange = [webView.selectedTextRange retain];

    } else if (gesture.state == UIGestureRecognizerStateChanged) {

        CGPoint offset = [gesture translationInView:tv];
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
            CGPoint velo = [gesture velocityInView:tv];
            if (abs(previousVelocityPoint.x) < 1000 && abs(velo.x) / 1000 != 0)
                numberOfTouches += (abs(velo.x) / 1000);
            previousVelocityPoint = velo;
        }
        int scale = 16 / numberOfTouches ? : 1;
        int xPointChanged = offset.x / scale;
        int yPointsChanged = offset.y / scale;

        if ([webView respondsToSelector:@selector(positionFromPosition:inDirection:offset:)]) {
            UITextPosition *position = nil;
            // Horizontal Move.
            if (beginningTextRange.isEmpty) {
                position = [webView positionFromPosition:beginningTextRange.start
                    inDirection:xPointChanged < 0 ? UITextLayoutDirectionLeft : UITextLayoutDirectionRight
                    offset:abs(xPointChanged)];
            } else {
                position = [webView positionFromPosition:isLeftPanning ? beginningTextRange.start : beginningTextRange.end
                    inDirection:xPointChanged < 0 ? UITextLayoutDirectionLeft : UITextLayoutDirectionRight
                    offset:abs(xPointChanged)];
            }
            // Vertical Move.
            if (verticalScrollLockAnsMoveIsEnabled) {
                position = [webView positionFromPosition:position
                    inDirection:yPointsChanged < 0 ? UITextLayoutDirectionUp : UITextLayoutDirectionDown
                    offset:abs(yPointsChanged)];
            }
            // over edge correction.
            if (!position) {
                position = xPointChanged < 0 ? webView.beginningOfDocument : webView.endOfDocument;
            }

            // ShiftCaret
            UITextRange *range;
            if (!isSelectionMode) {
                range = [webView textRangeFromPosition:position toPosition:position];
            } else {
                if (beginningTextRange.isEmpty)
                    range = [webView textRangeFromPosition:beginningTextRange.start toPosition:position];
                else
                    range = [webView textRangeFromPosition:isLeftPanning ? beginningTextRange.end : beginningTextRange.start toPosition:position];
            }
            webView.selectedTextRange = range;
            // reveal for UITextField.
            [[%c(UIFieldEditor) sharedFieldEditor] revealSelection];
        }
    }
}
%end

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
    verticalScrollLockAnsMoveIsEnabled = verticalScrollLockAndMovePref ? [verticalScrollLockAndMovePref boolValue] : NO;
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
    }
}
