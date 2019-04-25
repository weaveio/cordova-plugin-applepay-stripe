//
//  AppDelegate+PaymentIntents.h
//  Burger Boss
//
//  Created by Vitaly Dubov on 25/04/2019.
//

#import "AppDelegate.h"

@interface AppDelegate (PaymentIntents)
- (BOOL)application:(UIApplication *_Nullable)application openURL:(NSURL *_Nullable)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *_Nullable)options;
- (BOOL)application:(UIApplication *_Nonnull)application continueUserActivity:(NSUserActivity *_Nullable)userActivity restorationHandler:(void (^_Nullable)(NSArray * _Nullable))restorationHandler;
@end
