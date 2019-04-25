//
//  SAPConfirmViewController.m
//  Burger Boss
//
//  Created by Vitaly Dubov on 25/04/2019.
//

#import "SAPConfirmViewController.h"
@import Stripe;

@interface SAPConfirmViewController () {}

@property (nonatomic, assign, readwrite) double total;
@property (nonatomic, strong) UILabel *totalLabel;

@end

@implementation  SAPConfirmViewController

- (void)dealloc
{
    NSLog(@"SAPConfirmViewController dealloc");
}

- (instancetype)initWithTotal:(double)total {
    self = [super init];
    if (self) {
        self.total = total;
        [self createViews];
    }
    return self;
}

- (void)createViews {
    self.view.backgroundColor = [UIColor colorWithRed:246.0 / 255.0 green:246.0 / 255.0 blue:246.0 / 255.0 alpha:1.0];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.backgroundColor = [UIColor clearColor];

    label.textColor = [UIColor blackColor];
    label.font = [UIFont systemFontOfSize:35];
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.text = [NSString stringWithFormat:@"Total: $%.2f", self.total];
    [self.view addSubview:label];

    label.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
                                              [label.leadingAnchor constraintGreaterThanOrEqualToAnchor:label.superview.leadingAnchor constant:20.0],
                                              [label.trailingAnchor constraintLessThanOrEqualToAnchor:label.superview.trailingAnchor constant:20.0],
                                              [label.topAnchor constraintEqualToAnchor:self.topLayoutGuide.bottomAnchor constant:40.0],
                                              [label.centerXAnchor constraintEqualToAnchor:label.superview.centerXAnchor]
                                              ]];

    self.totalLabel = label;

    PKPaymentButton *payButton = [[PKPaymentButton alloc] initWithPaymentButtonType:PKPaymentButtonTypePlain paymentButtonStyle:PKPaymentButtonStyleWhite];
    [payButton addTarget:self action:@selector(payAction:) forControlEvents:UIControlEventTouchUpInside];
    payButton.layer.cornerRadius = 7.0;
    payButton.layer.borderWidth = 3.0;
    payButton.layer.borderColor = [UIColor blackColor].CGColor;
    payButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:payButton];

    [NSLayoutConstraint activateConstraints:@[
                                              [payButton.widthAnchor constraintEqualToConstant:164.0],
                                              [payButton.heightAnchor constraintEqualToConstant:100.0],
                                              [payButton.centerXAnchor constraintEqualToAnchor:payButton.superview.centerXAnchor],
                                              [payButton.centerYAnchor constraintEqualToAnchor:payButton.superview.centerYAnchor constant:-50.0]
                                              ]];

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelAction:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Confirm Payment";
}

- (void)cancelAction: (UIBarButtonItem *)sender {
    [self.delegate SAPConfirmViewControllerDidCancel:self];
}

- (void)payAction: (UIButton *)sender {
    [self.delegate SAPConfirmViewControllerDidConfirm:self];
}

@end
