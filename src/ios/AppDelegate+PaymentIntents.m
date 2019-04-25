//
//  AppDelegate+PaymentIntents.m
//  Burger Boss
//
//  Created by Vitaly Dubov on 25/04/2019.
//

#import "AppDelegate+PaymentIntents.h"
@import Stripe;

@implementation AppDelegate (PaymentIntents)

// This method handles opening native URLs (e.g., "your-app://")
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    BOOL stripeHandled = [Stripe handleStripeURLCallbackWithURL:url];
    if (stripeHandled) {
        return YES;
    } else {
        // This was not a stripe url – do whatever url handling your app
        // normally does, if any.
    }
    return NO;
}

// This method handles opening universal link URLs (e.g., "https://example.com/stripe_ios_callback")
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray * _Nullable))restorationHandler {
    if (userActivity.activityType == NSUserActivityTypeBrowsingWeb) {
        if (userActivity.webpageURL) {
            BOOL stripeHandled = [Stripe handleStripeURLCallbackWithURL:userActivity.webpageURL];
            if (stripeHandled) {
                return YES;
            } else {
                // This was not a stripe url – do whatever url handling your app
                // normally does, if any.
            }
        }
    }
    return NO;
}

@end
