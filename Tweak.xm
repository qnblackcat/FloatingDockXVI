#import <UIKit/UIKit.h>

static NSString *const preferencesDomain = @"com.nahtedetihw.floatingdockxviprefs";
static NSString *const preferencesNotification = @"com.nahtedetihw.floatingdockxviprefs/ReloadPrefs";

@interface SBFloatingDockPlatterView : UIView
@property (nonatomic) UIView *backgroundView;
@end

@interface SBIconListGridLayoutConfiguration : NSObject
@property (nonatomic) unsigned long long numberOfPortraitRows;
@end

@interface SBIconListView : UIView
@property (nonatomic) NSString *iconLocation;
@end

@interface SBMainSwitcherControllerCoordinator : UIViewController
+ (id)sharedInstance;
- (bool)isAnySwitcherVisible;
@end

@interface SBMainSwitcherViewController : UIViewController
+ (id)sharedInstance;
- (bool)isMainSwitcherVisible;
@end

@interface SBFloatingDockController : NSObject
-(void)_dismissFloatingDockIfPresentedAnimated:(BOOL)arg1 completionHandler:(/*^block*/id)arg2;
-(void)_presentFloatingDockIfDismissedAnimated:(BOOL)arg1 completionHandler:(/*^block*/id)arg2;
@end

@interface SBFloatingDockBehaviorAssertion : NSObject
@property (nonatomic, readonly) SBFloatingDockController *floatingDockController;
@end

@interface SBHomeScreenViewController : UIViewController
@property (nonatomic) SBFloatingDockBehaviorAssertion *homeScreenFloatingDockAssertion;
@end

@interface SBIconController : UIViewController
+ (id)sharedInstance;
@property (nonatomic, readonly) SBFloatingDockController *floatingDockController;
@end

@interface SBBestAppSuggestion : NSObject
- (BOOL)isHandoff;
@end

@interface SBFloatingDockSuggestionsModel : NSObject
@property (nonatomic,readonly) SBBestAppSuggestion * currentAppSuggestion;
@end

@interface SpringBoard : UIApplication
-(BOOL)isShowingHomescreen;
@end

// Values of the "Disable dock in:" segment in the settings pane.
typedef NS_ENUM(NSInteger, FDXDockVisibility) {
    FDXDockHiddenInApps = 0,
    FDXDockHiddenInSwitcher = 1,
    FDXDockHiddenInBoth = 2,
    FDXDockAlwaysVisible = 3,
};

// Values of the dock style segment in the settings pane.
typedef NS_ENUM(NSInteger, FDXDockStyle) {
    FDXDockStyleRecents = 0,
    FDXDockStyleLibrary = 1,
    FDXDockStyleBoth = 2,
    FDXDockStyleNone = 3,
};

static BOOL enabled, hideDockBG, removeSeparator;
static NSInteger dockStyle, maxRecents, maxDockIcons, dockVisibility;

static BOOL dockHiddenInApps() {
    return dockVisibility == FDXDockHiddenInApps || dockVisibility == FDXDockHiddenInBoth;
}

static BOOL dockHiddenInSwitcher() {
    return dockVisibility == FDXDockHiddenInSwitcher || dockVisibility == FDXDockHiddenInBoth;
}

static BOOL recentsEnabled() {
    return dockStyle == FDXDockStyleRecents || dockStyle == FDXDockStyleBoth;
}

static BOOL appLibraryEnabled() {
    return dockStyle == FDXDockStyleLibrary || dockStyle == FDXDockStyleBoth;
}

static BOOL isShowingHomescreen() {
    return [((SpringBoard *)[%c(SpringBoard) sharedApplication]) isShowingHomescreen];
}

static BOOL isSwitcherVisible() {
    if (@available(iOS 16.0, *)) return [[%c(SBMainSwitcherControllerCoordinator) sharedInstance] isAnySwitcherVisible];
    return [[%c(SBMainSwitcherViewController) sharedInstance] isMainSwitcherVisible];
}

static __weak SBHomeScreenViewController *homeScreenViewController;
static __weak SBFloatingDockController *lastFloatingDockController;

// iOS 17: SBIconController is no longer a UIViewController, so it doesn't respond to -parentViewController.
// Resolve the dock controller defensively instead of assuming any one path exists.
static SBFloatingDockController *currentFloatingDockController() {
    id iconController = [%c(SBIconController) sharedInstance];

    id homeVC = homeScreenViewController;
    if (!homeVC && [iconController respondsToSelector:@selector(parentViewController)]) homeVC = [iconController parentViewController];
    if ([homeVC respondsToSelector:@selector(homeScreenFloatingDockAssertion)]) {
        id assertion = [homeVC homeScreenFloatingDockAssertion];
        if ([assertion respondsToSelector:@selector(floatingDockController)]) {
            id controller = [assertion floatingDockController];
            if (controller) return controller;
        }
    }

    if ([iconController respondsToSelector:@selector(floatingDockController)]) {
        id controller = [iconController floatingDockController];
        if (controller) return controller;
    }

    id app = [%c(SpringBoard) sharedApplication];
    if ([app respondsToSelector:@selector(windowSceneManager)]) {
        id sceneManager = [app performSelector:@selector(windowSceneManager)];
        if ([sceneManager respondsToSelector:@selector(embeddedDisplayWindowScene)]) {
            id windowScene = [sceneManager performSelector:@selector(embeddedDisplayWindowScene)];
            if ([windowScene respondsToSelector:@selector(floatingDockController)]) {
                id controller = [windowScene performSelector:@selector(floatingDockController)];
                if (controller) return controller;
            }
        }
    }

    return lastFloatingDockController;
}

static void showDock() {
    SBFloatingDockController *controller = currentFloatingDockController();
    if ([controller respondsToSelector:@selector(_presentFloatingDockIfDismissedAnimated:completionHandler:)]) [controller _presentFloatingDockIfDismissedAnimated:YES completionHandler:nil];
}

static void hideDock() {
    if (isShowingHomescreen()) return;
    SBFloatingDockController *controller = currentFloatingDockController();
    if ([controller respondsToSelector:@selector(_dismissFloatingDockIfPresentedAnimated:completionHandler:)]) [controller _dismissFloatingDockIfPresentedAnimated:YES completionHandler:nil];
}

static void updateDockForSwitcher(BOOL switcherVisible) {
    if (!dockHiddenInSwitcher()) return;
    BOOL showingHomescreen = isShowingHomescreen();
    if (showingHomescreen && !switcherVisible) showDock();
    else if (!showingHomescreen && switcherVisible) hideDock();
}

static void loadPreferences() {
    // Read through cfprefsd so it matches what the Settings pane writes (also handles roothide's redirected prefs).
    CFPreferencesAppSynchronize((__bridge CFStringRef)preferencesDomain);
    NSDictionary *dict = nil;
    CFArrayRef keys = CFPreferencesCopyKeyList((__bridge CFStringRef)preferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (keys) {
        dict = (__bridge_transfer NSDictionary *)CFPreferencesCopyMultiple(keys, (__bridge CFStringRef)preferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        CFRelease(keys);
    }

    enabled = dict[@"enabled"] ? [dict[@"enabled"] boolValue] : NO;
    hideDockBG = dict[@"hideDockBG"] ? [dict[@"hideDockBG"] boolValue] : NO;
    removeSeparator = dict[@"removeSeparator"] ? [dict[@"removeSeparator"] boolValue] : NO;

    dockStyle = dict[@"dockStyle"] ? [dict[@"dockStyle"] integerValue] : FDXDockStyleRecents;
    maxRecents = dict[@"maxRecents"] ? [dict[@"maxRecents"] integerValue] : 3;
    maxDockIcons = dict[@"maxDockIcons"] ? [dict[@"maxDockIcons"] integerValue] : 4;
    dockVisibility = dict[@"dockVisibility"] ? [dict[@"dockVisibility"] integerValue] : FDXDockHiddenInApps;
}

%group FloatingDockXVI
%hook SBFloatingDockController
+ (BOOL)isFloatingDockSupported {
    return YES;
}

- (void)_configureFloatingDockBehaviorAssertionForOpenFolder:(id)arg1 atLevel:(NSUInteger)arg2 {
    lastFloatingDockController = self;
}

- (BOOL)_canPresentFloatingDock {
    lastFloatingDockController = self;
    return %orig;
}
%end

%hook SBHomeScreenViewController
- (void)viewDidLoad {
    %orig;
    homeScreenViewController = self;
}
%end

%hook SBFloatingDockPlatterView
- (void)setBackgroundView:(id)arg1 {
    %orig;
    if (hideDockBG) {
        self.backgroundView.hidden = YES;
    }
}
%end

%hook SBFloatingDockView
- (void)updateDividerVisualStyling {
    if (removeSeparator) return;
    %orig;
}
%end

%hook SBFloatingDockDefaults
- (void)setRecentsEnabled:(BOOL)arg1 {
    %orig(recentsEnabled());
}
- (BOOL)recentsEnabled {
    return recentsEnabled();
}
- (void)setAppLibraryEnabled:(BOOL)arg1 {
    %orig(appLibraryEnabled());
}
- (BOOL)appLibraryEnabled {
    return appLibraryEnabled();
}
%end

// control number of icons in dock
%hook SBIconListGridLayoutConfiguration
- (unsigned long long)numberOfPortraitColumns {
    unsigned long long o = %orig;
    if ([self numberOfPortraitRows] == 1 && o == 4) {
        return maxDockIcons;
    }
    return o;
}
%end

%hook SBIconListView
- (unsigned long long)maximumIconCount {
    if ([self.iconLocation isEqualToString:@"SBIconLocationDock"]) {
        return maxDockIcons;
    }
    return %orig;
}
%end

%hook SBFluidSwitcherViewController
- (BOOL)isFloatingDockGesturePossible {
    return !dockHiddenInApps();
}
- (BOOL)isFloatingDockSupported {
    // "Both" hides the switcher dock through updateDockForSwitcher(), so only "Switcher" reports unsupported here.
    if (isSwitcherVisible()) return dockVisibility != FDXDockHiddenInSwitcher;
    return !dockHiddenInApps();
}
%end

%hook SBMainSwitcherControllerCoordinator
-(void)layoutStateTransitionCoordinator:(id)arg1 transitionDidBeginWithTransitionContext:(id)arg2 {
    %orig;
    updateDockForSwitcher([[%c(SBMainSwitcherControllerCoordinator) sharedInstance] isAnySwitcherVisible]);
}
%end

%hook SBMainSwitcherViewController
-(void)layoutStateTransitionCoordinator:(id)arg1 transitionDidBeginWithTransitionContext:(id)arg2 {
    %orig;
    updateDockForSwitcher([[%c(SBMainSwitcherViewController) sharedInstance] isMainSwitcherVisible]);
}
%end
%end

%group Recents
%hook SBFloatingDockSuggestionsModel
-(BOOL)recentDisplayItemsController:(id)arg1 shouldAddItem:(id)arg2 {
    if ([self.currentAppSuggestion isHandoff]) return NO;
    return %orig;
}

-(unsigned long long)maxSuggestions {
    return maxRecents;
}
%end

%hook SBFloatingDockSuggestionsViewController
-(id)initWithNumberOfRecents:(unsigned long long)arg1 iconController:(id)arg2 applicationController:(id)arg3 layoutStateTransitionCoordinator:(id)arg4 suggestionsModel:(id)arg5 iconViewProvider:(id)arg6 {
    return %orig(maxRecents,arg2,arg3,arg4,arg5,arg6);
}
%end
%end

%group Recents16
%hook SBFloatingDockSuggestionsModel
// iOS 16+ method to restrict max recents in dock
- (id)initWithMaximumNumberOfSuggestions:(NSUInteger)arg1 iconController:(id)arg2 recentsController:(id)arg3 recentsDataStore:(id)arg4 recentsDefaults:(id)arg5 floatingDockDefaults:(id)arg6 appSuggestionManager:(id)arg7 applicationController:(id)arg8 {
    return %orig(maxRecents,arg2,arg3,arg4,arg5,arg6,arg7,arg8);
}
%end
%end

%group Recents15
%hook SBFloatingDockSuggestionsModel
// iOS 15 method to restrict max recents in dock
-(id)initWithMaximumNumberOfSuggestions:(unsigned long long)arg1 iconController:(id)arg2 recentsController:(id)arg3 recentsDataStore:(id)arg4 recentsDefaults:(id)arg5 floatingDockDefaults:(id)arg6 appSuggestionManager:(id)arg7 analyticsClient:(id)arg8 applicationController:(id)arg9 {
    return %orig(maxRecents,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9);
}
%end
%end

%ctor {
    loadPreferences();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPreferences, (__bridge CFStringRef)preferencesNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);

    if (!enabled) return;
    %init(FloatingDockXVI);
    %init(Recents);
    if (@available(iOS 16.0, *)) {
        %init(Recents16);
    } else {
        %init(Recents15);
    }
}
