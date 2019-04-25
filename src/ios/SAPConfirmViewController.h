//
//  SAPConfirmViewController.h
//  Burger Boss
//
//  Created by Vitaly Dubov on 25/04/2019.
//

#import <UIKit/UIKit.h>

@class SAPConfirmViewController;
@protocol SAPConfirmViewControllerDelegate <NSObject>
- (void)SAPConfirmViewControllerDidCancel:(SAPConfirmViewController *)controller;
- (void)SAPConfirmViewControllerDidConfirm:(SAPConfirmViewController *)controller;
- (void)SAPConfirmViewControllerDidFail:(SAPConfirmViewController *)controller error:(NSError *)error;
@end

@interface SAPConfirmViewController: UIViewController {}

@property (nonatomic, assign, readonly) double total;
@property (nonatomic, weak) NSObject<SAPConfirmViewControllerDelegate> *delegate;

- (instancetype)initWithTotal:(double)total;

@end
