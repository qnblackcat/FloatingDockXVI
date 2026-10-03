#import <Foundation/Foundation.h>
#import "FDXVIPreferences.h"
#import <AudioToolbox/AudioServices.h>

static NSString *const preferencesDomain = @"com.nahtedetihw.floatingdockxviprefs";

// Resolve paths from the loaded bundle so it works on rootful, rootless (/var/jb) and roothide (randomized jbroot).
static NSString *prefsBundlePath(void) {
    return [[[NSBundle bundleForClass:[FDXVIPreferencesListController class]] bundlePath] stringByAppendingString:@"/"];
}

// <jbroot>/Library/PreferenceBundles/floatingdockxviprefs.bundle -> <jbroot>
static NSString *jbrootPath(void) {
    return [[[[[NSBundle bundleForClass:[FDXVIPreferencesListController class]] bundlePath] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
}

#define bundlePath prefsBundlePath()

#define SettingsColor [UIColor colorWithRed:119/255.0f green:181/255.0f blue:166/255.0f alpha:1.0f]
#define AccentColor [UIColor colorWithRed:15/255.0f green:130/255.0f blue:193/255.0f alpha:1.0f]

static UIBarButtonItem *respringButtonItem;
static UIViewController *popController;

static UIWindow *currentWindow(void) {
    return [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
}

@implementation FDXVIPreferencesListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }

    return _specifiers;
}

- (UITableViewStyle)tableViewStyle {
    return UITableViewStyleInsetGrouped;
}

- (instancetype)init {

    self = [super init];

    if (self) {

        respringButtonItem = [self barButtonWithImageNamed:@"CHECKMARK.png" action:@selector(apply:)];
        self.navigationItem.rightBarButtonItems = @[
            respringButtonItem,
            [self barButtonWithImageNamed:@"TWITTER.png" action:@selector(twitter:)],
            [self barButtonWithImageNamed:@"PAYPAL.png" action:@selector(paypal:)],
        ];
        self.navigationItem.titleView = [UIView new];
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.titleLabel.text = @"";
        self.titleLabel.textColor = SettingsColor;
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        [self.navigationItem.titleView addSubview:self.titleLabel];

        self.iconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        self.iconView.contentMode = UIViewContentModeScaleAspectFit;
        self.iconView.image = [UIImage imageWithContentsOfFile:[bundlePath stringByAppendingString:@"icon.png"]];
        self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
        self.iconView.alpha = 0.0;
        [self.navigationItem.titleView addSubview:self.iconView];

        [NSLayoutConstraint activateConstraints:@[
            [self.titleLabel.topAnchor constraintEqualToAnchor:self.navigationItem.titleView.topAnchor],
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.navigationItem.titleView.leadingAnchor],
            [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.navigationItem.titleView.trailingAnchor],
            [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.navigationItem.titleView.bottomAnchor],
            [self.iconView.topAnchor constraintEqualToAnchor:self.navigationItem.titleView.topAnchor],
            [self.iconView.leadingAnchor constraintEqualToAnchor:self.navigationItem.titleView.leadingAnchor],
            [self.iconView.trailingAnchor constraintEqualToAnchor:self.navigationItem.titleView.trailingAnchor],
            [self.iconView.bottomAnchor constraintEqualToAnchor:self.navigationItem.titleView.bottomAnchor],
        ]];

    }

    return self;

}

- (UIBarButtonItem *)barButtonWithImageNamed:(NSString *)imageName action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0,0,30,30);
    button.layer.cornerRadius = button.frame.size.height / 2;
    button.layer.masksToBounds = YES;
    button.backgroundColor = SettingsColor;
    button.tintColor = AccentColor;
    [button setImage:[[UIImage imageWithContentsOfFile:[bundlePath stringByAppendingString:imageName]] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return [[UIBarButtonItem alloc] initWithCustomView:button];
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {

    return UIModalPresentationNone;
}

- (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];

    currentWindow().tintColor = SettingsColor;
    self.navigationController.navigationController.navigationBar.translucent = YES;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.tableHeaderView != self.headerView) tableView.tableHeaderView = self.headerView;
    return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (void)viewDidLoad {

    [super viewDidLoad];

    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0,0,200,200)];
    self.headerImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0,0,200,200)];
    self.headerImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.headerImageView.image = [UIImage imageWithContentsOfFile:[bundlePath stringByAppendingString:@"banner.png"]];
    self.headerImageView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.headerView addSubview:self.headerImageView];
    [NSLayoutConstraint activateConstraints:@[
        [self.headerImageView.topAnchor constraintEqualToAnchor:self.headerView.topAnchor],
        [self.headerImageView.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor],
        [self.headerImageView.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor],
        [self.headerImageView.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor],
    ]];

    _table.tableHeaderView = self.headerView;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNoGesture:)
                                                     name:UIApplicationDidEnterBackgroundNotification object:nil];

}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat offsetY = scrollView.contentOffset.y;

    // Only animate when crossing the threshold instead of on every scroll tick.
    BOOL showIcon = offsetY > 40;
    if (showIcon != (self.iconView.alpha > 0.5)) {
        [UIView animateWithDuration:0.2 animations:^{
            self.iconView.alpha = showIcon ? 1.0 : 0.0;
            self.titleLabel.alpha = showIcon ? 0.0 : 1.0;
        }];
    }

    if (offsetY > 0) offsetY = 0;
    self.headerImageView.frame = CGRectMake(self.headerView.frame.origin.x, self.headerView.frame.origin.y, self.headerView.frame.size.width, 200 - offsetY);
}

- (void)_unloadBundleControllers {
    [super _unloadBundleControllers];

    currentWindow().tintColor = nil;
}

// Go through cfprefsd instead of writing the plist by hand: the hardcoded /var/jb path doesn't exist on roothide,
// so the write silently failed and the switches reverted to their defaults.
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = specifier.properties[@"key"];
    if (!key) return specifier.properties[@"default"];
    CFPreferencesAppSynchronize((__bridge CFStringRef)preferencesDomain);
    id value = (__bridge_transfer id)CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)preferencesDomain);
    return value ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = specifier.properties[@"key"];
    if (!key) return;
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)preferencesDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)preferencesDomain);
    NSString *notification = specifier.properties[@"PostNotification"];
    if (notification) CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)notification, NULL, NULL, YES);
}

- (void)apply:(UIButton *)sender {
    
    popController = [[UIViewController alloc] init];
    popController.modalPresentationStyle = UIModalPresentationPopover;
    popController.preferredContentSize = CGSizeMake(200,130);
    UILabel *respringLabel = [[UILabel alloc] init];
    respringLabel.frame = CGRectMake(20, 20, 160, 60);
    respringLabel.numberOfLines = 2;
    respringLabel.textAlignment = NSTextAlignmentCenter;
    respringLabel.adjustsFontSizeToFitWidth = YES;
    respringLabel.font = [UIFont boldSystemFontOfSize:20];
    respringLabel.textColor = AccentColor;
    respringLabel.text = @"Are you sure you want to respring?";
    [popController.view addSubview:respringLabel];

    [popController.view addSubview:[self popoverButtonWithTitle:@"Yes" frame:CGRectMake(100, 100, 100, 30) action:@selector(handleYesGesture)]];
    [popController.view addSubview:[self popoverButtonWithTitle:@"No" frame:CGRectMake(0, 100, 100, 30) action:@selector(handleNoGesture:)]];

    UIPopoverPresentationController *popover = popController.popoverPresentationController;
    popover.delegate = self;
    popover.permittedArrowDirections = UIPopoverArrowDirectionUp;
    popover.barButtonItem = respringButtonItem;
    popover.backgroundColor = SettingsColor;
    
    [self presentViewController:popController animated:YES completion:nil];
    
    AudioServicesPlaySystemSound(1519);

}

- (UIButton *)popoverButtonWithTitle:(NSString *)title frame:(CGRect)frame action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = frame;
    button.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:AccentColor forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)twitter:(id)sender {
    AudioServicesPlaySystemSound(1519);
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://twitter.com/EthanWhited"] options:@{} completionHandler:nil];
}

- (void)paypal:(id)sender {
    AudioServicesPlaySystemSound(1519);
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://paypal.me/nahtedetihw"] options:@{} completionHandler:nil];
}

- (void)handleYesGesture {
    AudioServicesPlaySystemSound(1519);

    [popController dismissViewControllerAnimated:YES completion:nil];
    
    pid_t pid;
    const char* args[] = {"killall", "SpringBoard", NULL};
    for (NSString *path in @[[jbrootPath() stringByAppendingPathComponent:@"usr/bin/killall"], @"/var/jb/usr/bin/killall", @"/usr/bin/killall"]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            posix_spawn(&pid, path.fileSystemRepresentation, NULL, NULL, (char* const*)args, NULL);
            break;
        }
    }
}

- (void)handleNoGesture:(UIButton *)sender {
    [popController dismissViewControllerAnimated:YES completion:nil];
}

@end
