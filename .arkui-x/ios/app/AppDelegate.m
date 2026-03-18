#import "AppDelegate.h"
#import "EntryEntryAbilityViewController.h"
#import <libarkui_ios/StageApplication.h>

#define BUNDLE_DIRECTORY @"arkui-x"
#define BUNDLE_NAME @"com.bytemain.soduku"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [StageApplication configModuleWithBundleDirectory:BUNDLE_DIRECTORY];
    [StageApplication launchApplication];

    NSString *instanceName = [NSString stringWithFormat:@"%@:%@:%@",
                              BUNDLE_NAME, @"entry", @"EntryAbility"];

    EntryEntryAbilityViewController *mainVC =
        [[EntryEntryAbilityViewController alloc] initWithInstanceName:instanceName];

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = mainVC;
    [self.window makeKeyAndVisible];

    return YES;
}

@end
