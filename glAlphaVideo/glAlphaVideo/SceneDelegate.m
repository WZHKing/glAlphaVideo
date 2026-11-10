//
//  SceneDelegate.m
//  glAlphaVideo
//

#import "SceneDelegate.h"
#import "ViewController.h"

@implementation SceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }

    UIWindowScene *windowScene = (UIWindowScene *)scene;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:windowScene];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:[[ViewController alloc] init]];
    window.rootViewController = navigationController;
    window.backgroundColor = [UIColor whiteColor];
    [window makeKeyAndVisible];
    self.window = window;
}

@end
