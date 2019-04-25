#import "CDVApplePay.h"
@import AddressBook;
@import Stripe;
#import "SAPConfirmViewController.h"
#import "AppDelegate+PaymentIntents.h"

#pragma mark - CDVApplePay implementation

@interface CDVApplePay () <SAPConfirmViewControllerDelegate>
@property (nonatomic, strong) SAPConfirmViewController *confirmViewController;
@property (nonatomic, strong) CDVInvokedUrlCommand *paymentCommand;
@property (nonatomic, strong) PKPaymentRequest *paymentRequest;
@property (nonatomic, strong) STPRedirectContext *redirectContext;
@end

@implementation CDVApplePay

- (void)pluginInitialize
{

    // Set these to the payment cards accepted.
    // They will nearly always be the same.
    supportedPaymentNetworks = @[PKPaymentNetworkVisa, PKPaymentNetworkMasterCard, PKPaymentNetworkAmex];

    // Set the capabilities that your merchant supports
    // Adyen for example, only supports the 3DS one.
    merchantCapabilities = PKMerchantCapability3DS;// PKMerchantCapabilityEMV;

    // Stripe Publishable Key
    NSString * stripePublishableKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"StripePublishableKey"];
    NSLog(@"Stripe stripePublishableKey == %@", stripePublishableKey);
    NSString * appleMerchantIdentifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"AppleMerchantIdentifier"];
    NSLog(@"ApplePay appleMerchantIdentifier == %@", appleMerchantIdentifier);
    [[STPPaymentConfiguration sharedConfiguration] setPublishableKey:stripePublishableKey];
    [[STPPaymentConfiguration sharedConfiguration] setAppleMerchantIdentifier:appleMerchantIdentifier];
}

#pragma mark - Public

- (void)canMakePayments:(CDVInvokedUrlCommand*)command
{
    if ([PKPaymentAuthorizationViewController canMakePayments]) {
        if ((floor(NSFoundationVersionNumber) < NSFoundationVersionNumber_iOS_8_0)) {
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"This device cannot make payments."];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        } else if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){9, 0, 0}]) {
            if ([PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:supportedPaymentNetworks capabilities:(merchantCapabilities)]) {
                CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: @"This device can make payments and has a supported card"];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                return;
            } else {
                CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"This device can make payments but has no supported cards"];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                return;
            }
        } else if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){8, 0, 0}]) {
            if ([PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:supportedPaymentNetworks]) {
                CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: @"This device can make payments and has a supported card"];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                return;
            } else {
                CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"This device can make payments but has no supported cards"];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                return;
            }
        } else {
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"This device cannot make payments."];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }
    } else {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"This device cannot make payments."];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }
}

- (void)completeLastTransaction:(CDVInvokedUrlCommand*)command
{
    if (self.paymentAuthorizationBlock) {

        NSString *paymentAuthorizationStatusString = [command.arguments objectAtIndex:0];
        NSDictionary *intentObject = [command.arguments objectAtIndex:1];

        NSLog(@"ApplePay completeLastTransaction == %@, intentObject = %@", paymentAuthorizationStatusString, intentObject);

        void(^sendSuccessResult)(void) = ^(void) {
            PKPaymentAuthorizationStatus paymentAuthorizationStatus = [self paymentAuthorizationStatusFromArgument:paymentAuthorizationStatusString];
            self.paymentAuthorizationBlock(paymentAuthorizationStatus);

            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: @"Payment status applied."];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        };

        void(^sendFailureResult)(NSString *) = ^(NSString *message) {
            PKPaymentAuthorizationStatus paymentAuthorizationStatus = PKPaymentAuthorizationStatusFailure;
            self.paymentAuthorizationBlock(paymentAuthorizationStatus);

            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        };

        STPPaymentIntent *paymentIntent = [STPPaymentIntent decodedObjectFromAPIResponse:intentObject];
        NSLog(@"paymentIntent.status = %d", paymentIntent.status);
        if (paymentIntent.status == STPPaymentIntentStatusRequiresAction) {
            // Note you must retain this for the duration of the redirect flow - it dismisses any presented view controller upon deallocation.
            self.redirectContext = [[STPRedirectContext alloc] initWithPaymentIntent:paymentIntent completion:^(NSString *clientSecret, NSError *redirectError) {
                // Fetch the latest status of the Payment Intent if necessary
                [[STPAPIClient sharedClient] retrievePaymentIntentWithClientSecret:clientSecret completion:^(STPPaymentIntent *paymentIntent, NSError *error) {
                    // Check paymentIntent.status
                    if (paymentIntent.status == STPPaymentIntentStatusSucceeded) {
                        sendSuccessResult();
                    }
                }];
            }];
            if (self.redirectContext) {
                // opens SFSafariViewController to the necessary URL
                [self.redirectContext startRedirectFlowFromViewController:self.confirmViewController];
            } else {
                // This PaymentIntent action is not yet supported by the SDK.
                sendFailureResult(@"This PaymentIntent action is not yet supported by the SDK");
            }
        } else {
            // Show success message
            sendSuccessResult();
        }
    }
}

- (void)confirmAndMakePaymentRequest:(CDVInvokedUrlCommand*)command {
    NSArray<PKPaymentSummaryItem *> *items = [self itemsFromArguments:command.arguments];
    double total = 0.0;

    for (PKPaymentSummaryItem *item in items) {
        total += item.amount.doubleValue;
    }

    if (total > 0 && [PKPaymentAuthorizationViewController canMakePayments] == YES) {
        [self showConfirm:total command:command];
    } else {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Cannot make payments"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void)makePaymentRequest:(CDVInvokedUrlCommand*)command
{
    self.paymentCallbackId = command.callbackId;

    NSLog(@"Stripe deviceSupportsApplePay == %s", [Stripe deviceSupportsApplePay] ? "true" : "false");
    NSLog(@"ApplePay canMakePayments == %s", [PKPaymentAuthorizationViewController canMakePayments]? "true" : "false");
    if ([PKPaymentAuthorizationViewController canMakePayments] == NO) {
        [self hideConfirm];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"This device cannot make payments."];
        [self.commandDelegate sendPluginResult:result callbackId:self.paymentCallbackId];
        return;
    }

    // reset any lingering callbacks, incase the previous payment failed.
    self.paymentAuthorizationBlock = nil;

    NSString * appleMerchantIdentifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"AppleMerchantIdentifier"];
    PKPaymentRequest *request = [Stripe paymentRequestWithMerchantIdentifier:appleMerchantIdentifier
                                                                     country:[self countryCodeFromArguments:command.arguments]
                                                                    currency:[self currencyCodeFromArguments:command.arguments]];

    // Different version of iOS support different networks, (ie Discover card is iOS9+; not part of my project, so ignoring).
    request.supportedNetworks = supportedPaymentNetworks;

    request.merchantCapabilities = merchantCapabilities;

    // All this data is loaded from the Cordova object passed in. See documentation.
    [request setMerchantIdentifier:appleMerchantIdentifier];
    [request setRequiredBillingAddressFields:[self billingAddressRequirementFromArguments:command.arguments]];
    [request setRequiredShippingAddressFields:[self shippingAddressRequirementFromArguments:command.arguments]];
    [request setShippingType:[self shippingTypeFromArguments:command.arguments]];
    [request setShippingMethods:[self shippingMethodsFromArguments:command.arguments]];
    [request setPaymentSummaryItems:[self itemsFromArguments:command.arguments]];
    self.paymentRequest = request;

    NSLog(@"ApplePay request == %@", request);

    PKPaymentAuthorizationViewController *authVC = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:request];

    authVC.delegate = self;

    if (authVC == nil) {
        [self hideConfirm];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"PKPaymentAuthorizationViewController was nil."];
        [self.commandDelegate sendPluginResult:result callbackId:self.paymentCallbackId];
        return;
    }

    [self.confirmViewController presentViewController:authVC animated:YES completion:nil];
}

#pragma mark - Helpers

- (NSMutableDictionary*)applyABRecordBillingAddress:(ABRecordRef)address forDictionary:(NSMutableDictionary*)response {
    NSString *address1;
    NSString *city;
    NSString *postcode;
    NSString *state;
    NSString *country;
    NSString *countryCode;
    //NSString *emailAddress;


    // TODO: Validate email

    //    if (shippingContact.emailAddress) {
    //        [response setObject:shippingContact.emailAddress forKey:@"billingEmailAddress"];
    //    }
    //
    //    if (shippingContact.supplementarySubLocality) {
    //        [response setObject:shippingContact.supplementarySubLocality forKey:@"billingSupplementarySubLocality"];
    //    }


    //emailAddress = (__bridge NSString *)(CFDictionaryGetValue(address, kABPersonEmailProperty));


    ABMultiValueRef addressRecord = ABRecordCopyValue(address, kABPersonAddressProperty);
    if (ABMultiValueGetCount(addressRecord) > 0) {
        CFDictionaryRef dict = ABMultiValueCopyValueAtIndex(addressRecord, 0);

        address1 = (__bridge NSString *)(CFDictionaryGetValue(dict, kABPersonAddressStreetKey));
        city = (__bridge NSString *)(CFDictionaryGetValue(dict, kABPersonAddressCityKey));
        postcode = (__bridge NSString *)(CFDictionaryGetValue(dict, kABPersonAddressZIPKey));
        state = (__bridge NSString *)(CFDictionaryGetValue(dict, kABPersonAddressStateKey));
        country = (__bridge NSString *)(CFDictionaryGetValue(dict, kABPersonAddressCountryKey));
        countryCode = (__bridge NSString *)(CFDictionaryGetValue(dict, kABPersonAddressCountryCodeKey));


        if (address1) {
            [response setObject:address1 forKey:@"billingAddressStreet"];
        }

        if (city) {
            [response setObject:city forKey:@"billingAddressCity"];
        }

        if (postcode) {
            [response setObject:postcode forKey:@"billingPostalCode"];
        }

        if (state) {
            [response setObject:state forKey:@"billingAddressState"];
        }

        if (country) {
            [response setObject:country forKey:@"billingCountry"];
        }

        if (countryCode) {
            [response setObject:countryCode forKey:@"billingISOCountryCode"];
        }

    }

    // TODO: Valdidate address

    //    BOOL valid = (address1 && ![address1 isEqualToString:@""] &&
    //                  city && ![city isEqualToString:@""] &&
    //                  postcode && ![postcode isEqualToString:@""] &&
    //                  country && ![country isEqualToString:@""]);
    //
    //    if ([selectedCountry isEqualToString:@"United States"]) {
    //        valid = (valid && state && ![state isEqualToString:@""]);
    //    }
    return response;
}

- (NSMutableDictionary*)applyABRecordShippingAddress:(ABRecordRef)address forDictionary:(NSMutableDictionary*)response {
    NSString *address1;
    NSString *city;
    NSString *postcode;
    NSString *state;
    NSString *country;
    NSString *countryCode;
    //NSString *emailAddress;


    // TODO: Validate email

    //    if (shippingContact.emailAddress) {
    //        [response setObject:shippingContact.emailAddress forKey:@"shippingEmailAddress"];
    //    }
    //
    //    if (shippingContact.supplementarySubLocality) {
    //        [response setObject:shippingContact.supplementarySubLocality forKey:@"shippingSupplementarySubLocality"];
    //    }


    //emailAddress = (__bridge NSString *)(CFDictionaryGetValue(address, kABPersonEmailProperty));


    ABMultiValueRef addressRecord = ABRecordCopyValue(address, kABPersonAddressProperty);
    if (ABMultiValueGetCount(addressRecord) > 0) {
        CFDictionaryRef dict = ABMultiValueCopyValueAtIndex(addressRecord, 0);

        address1 = (__bridge NSString *)(CFDictionaryGetValue(dict, kABPersonAddressStreetKey));
        city = (__bridge NSString *)(CFDictionaryGetValue(dict, kABPersonAddressCityKey));
        postcode = (__bridge NSString *)(CFDictionaryGetValue(dict, kABPersonAddressZIPKey));
        state = (__bridge NSString *)(CFDictionaryGetValue(dict, kABPersonAddressStateKey));
        country = (__bridge NSString *)(CFDictionaryGetValue(dict, kABPersonAddressCountryKey));
        countryCode = (__bridge NSString *)(CFDictionaryGetValue(dict, kABPersonAddressCountryCodeKey));


        if (address1) {
            [response setObject:address1 forKey:@"shippingAddressStreet"];
        }

        if (city) {
            [response setObject:city forKey:@"shippingAddressCity"];
        }

        if (postcode) {
            [response setObject:postcode forKey:@"shippingPostalCode"];
        }

        if (state) {
            [response setObject:state forKey:@"shippingAddressState"];
        }

        if (country) {
            [response setObject:country forKey:@"shippingCountry"];
        }

        if (countryCode) {
            [response setObject:countryCode forKey:@"shippingISOCountryCode"];
        }

    }

    // TODO: Valdidate address

    //    BOOL valid = (address1 && ![address1 isEqualToString:@""] &&
    //                  city && ![city isEqualToString:@""] &&
    //                  postcode && ![postcode isEqualToString:@""] &&
    //                  country && ![country isEqualToString:@""]);
    //
    //    if ([selectedCountry isEqualToString:@"United States"]) {
    //        valid = (valid && state && ![state isEqualToString:@""]);
    //    }
    return response;
}

- (NSString *)countryCodeFromArguments:(NSArray *)arguments
{
    NSString *countryCode = [[arguments objectAtIndex:0] objectForKey:@"countryCode"];
    return countryCode;
}

- (NSString *)currencyCodeFromArguments:(NSArray *)arguments
{
    NSString *currencyCode = [[arguments objectAtIndex:0] objectForKey:@"currencyCode"];
    return currencyCode;
}

- (PKShippingType)shippingTypeFromArguments:(NSArray *)arguments
{
    NSString *shippingType = [[arguments objectAtIndex:0] objectForKey:@"shippingType"];

    if ([shippingType isEqualToString:@"shipping"]) {
        return PKShippingTypeShipping;
    } else if ([shippingType isEqualToString:@"delivery"]) {
        return PKShippingTypeDelivery;
    } else if ([shippingType isEqualToString:@"store"]) {
        return PKShippingTypeStorePickup;
    } else if ([shippingType isEqualToString:@"service"]) {
        return PKShippingTypeServicePickup;
    }


    return PKShippingTypeShipping;
}

- (PKAddressField)billingAddressRequirementFromArguments:(NSArray *)arguments
{
    NSString *billingAddressRequirement = [[arguments objectAtIndex:0] objectForKey:@"billingAddressRequirement"];

    if ([billingAddressRequirement isEqualToString:@"none"]) {
        return PKAddressFieldNone;
    } else if ([billingAddressRequirement isEqualToString:@"all"]) {
        return PKAddressFieldAll;
    } else if ([billingAddressRequirement isEqualToString:@"postcode"]) {
        return PKAddressFieldPostalAddress;
    } else if ([billingAddressRequirement isEqualToString:@"name"]) {
        return PKAddressFieldName;
    } else if ([billingAddressRequirement isEqualToString:@"email"]) {
        return PKAddressFieldEmail;
    } else if ([billingAddressRequirement isEqualToString:@"phone"]) {
        return PKAddressFieldPhone;
    }


    return PKAddressFieldNone;
}

- (PKAddressField)shippingAddressRequirementFromArguments:(NSArray *)arguments
{
    NSString *shippingAddressRequirement = [[arguments objectAtIndex:0] objectForKey:@"shippingAddressRequirement"];

    if ([shippingAddressRequirement isEqualToString:@"none"]) {
        return PKAddressFieldNone;
    } else if ([shippingAddressRequirement isEqualToString:@"all"]) {
        return PKAddressFieldAll;
    } else if ([shippingAddressRequirement isEqualToString:@"postcode"]) {
        return PKAddressFieldPostalAddress;
    } else if ([shippingAddressRequirement isEqualToString:@"name"]) {
        return PKAddressFieldName;
    } else if ([shippingAddressRequirement isEqualToString:@"email"]) {
        return PKAddressFieldEmail;
    } else if ([shippingAddressRequirement isEqualToString:@"phone"]) {
        return PKAddressFieldPhone;
    }


    return PKAddressFieldNone;
}

- (NSArray *)itemsFromArguments:(NSArray *)arguments
{
    NSArray *itemDescriptions = [[arguments objectAtIndex:0] objectForKey:@"items"];

    NSMutableArray *items = [[NSMutableArray alloc] init];

    for (NSDictionary *item in itemDescriptions) {

        NSString *label = [item objectForKey:@"label"];

        NSDecimalNumber *amount = [NSDecimalNumber decimalNumberWithDecimal:[[item objectForKey:@"amount"] decimalValue]];

        PKPaymentSummaryItem *newItem = [PKPaymentSummaryItem summaryItemWithLabel:label amount:amount];

        [items addObject:newItem];
    }

    return items;
}

- (NSArray *)shippingMethodsFromArguments:(NSArray *)arguments
{
    NSArray *shippingDescriptions = [[arguments objectAtIndex:0] objectForKey:@"shippingMethods"];

    NSMutableArray *shippingMethods = [[NSMutableArray alloc] init];


    for (NSDictionary *desc in shippingDescriptions) {

        NSString *identifier = [desc objectForKey:@"identifier"];
        NSString *detail = [desc objectForKey:@"detail"];
        NSString *label = [desc objectForKey:@"label"];

        NSDecimalNumber *amount = [NSDecimalNumber decimalNumberWithDecimal:[[desc objectForKey:@"amount"] decimalValue]];

        PKPaymentSummaryItem *newMethod = [self shippingMethodWithIdentifier:identifier detail:detail label:label amount:amount];

        [shippingMethods addObject:newMethod];
    }

    return shippingMethods;
}

- (PKPaymentAuthorizationStatus)paymentAuthorizationStatusFromArgument:(NSString *)paymentAuthorizationStatus
{

    if ([paymentAuthorizationStatus isEqualToString:@"success"]) {
        return PKPaymentAuthorizationStatusSuccess;
    } else if ([paymentAuthorizationStatus isEqualToString:@"failure"]) {
        return PKPaymentAuthorizationStatusFailure;
    } else if ([paymentAuthorizationStatus isEqualToString:@"invalid-billing-address"]) {
        return PKPaymentAuthorizationStatusInvalidBillingPostalAddress;
    } else if ([paymentAuthorizationStatus isEqualToString:@"invalid-shipping-address"]) {
        return PKPaymentAuthorizationStatusInvalidShippingPostalAddress;
    } else if ([paymentAuthorizationStatus isEqualToString:@"invalid-shipping-contact"]) {
        return PKPaymentAuthorizationStatusInvalidShippingContact;
    } else if ([paymentAuthorizationStatus isEqualToString:@"require-pin"]) {
        return PKPaymentAuthorizationStatusPINRequired;
    } else if ([paymentAuthorizationStatus isEqualToString:@"incorrect-pin"]) {
        return PKPaymentAuthorizationStatusPINIncorrect;
    } else if ([paymentAuthorizationStatus isEqualToString:@"locked-pin"]) {
        return PKPaymentAuthorizationStatusPINLockout;
    }

    return PKPaymentAuthorizationStatusFailure;
}

- (NSMutableDictionary*) formatPaymentForApplication:(PKPayment *)payment {
    NSString *paymentData = [payment.token.paymentData base64EncodedStringWithOptions:0];

    NSMutableDictionary *response = [[NSMutableDictionary alloc] init];

    [response setObject:paymentData  forKey:@"paymentData"];
    [response setObject:payment.token.transactionIdentifier  forKey:@"transactionIdentifier"];

    // Different version of iOS present the billing/shipping addresses in different ways. Pain.
    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){9, 0, 0}]) {


        PKContact *billingContact = payment.billingContact;
        if (billingContact) {
            if (billingContact.emailAddress) {
                [response setObject:billingContact.emailAddress forKey:@"billingEmailAddress"];
            }

            if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){9, 2, 0}]) {
                if (billingContact.supplementarySubLocality) {
                    [response setObject:billingContact.supplementarySubLocality forKey:@"billingSupplementarySubLocality"];
                }
            }

            if (billingContact.name) {

                if (billingContact.name.givenName) {
                    [response setObject:billingContact.name.givenName forKey:@"billingNameFirst"];
                }

                if (billingContact.name.middleName) {
                    [response setObject:billingContact.name.middleName forKey:@"billingNameMiddle"];
                }

                if (billingContact.name.familyName) {
                    [response setObject:billingContact.name.familyName forKey:@"billingNameLast"];
                }

            }

            if (billingContact.postalAddress) {

                if (billingContact.postalAddress.street) {
                    [response setObject:billingContact.postalAddress.street forKey:@"billingAddressStreet"];
                }

                if (billingContact.postalAddress.city) {
                    [response setObject:billingContact.postalAddress.city forKey:@"billingAddressCity"];
                }

                if (billingContact.postalAddress.state) {
                    [response setObject:billingContact.postalAddress.state forKey:@"billingAddressState"];
                }


                if (billingContact.postalAddress.postalCode) {
                    [response setObject:billingContact.postalAddress.postalCode forKey:@"billingPostalCode"];
                }

                if (billingContact.postalAddress.country) {
                    [response setObject:billingContact.postalAddress.country forKey:@"billingCountry"];
                }

                if (billingContact.postalAddress.ISOCountryCode) {
                    [response setObject:billingContact.postalAddress.ISOCountryCode forKey:@"billingISOCountryCode"];
                }

            }
        }

        PKContact *shippingContact = payment.shippingContact;
        if (shippingContact) {
            if (shippingContact.emailAddress) {
                [response setObject:shippingContact.emailAddress forKey:@"shippingEmailAddress"];
            }

            if (shippingContact.name) {

                if (shippingContact.name.givenName) {
                    [response setObject:shippingContact.name.givenName forKey:@"shippingNameFirst"];
                }

                if (shippingContact.name.middleName) {
                    [response setObject:shippingContact.name.middleName forKey:@"shippingNameMiddle"];
                }

                if (shippingContact.name.familyName) {
                    [response setObject:shippingContact.name.familyName forKey:@"shippingNameLast"];
                }

            }
            if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){9, 2, 0}]) {
                if (shippingContact.supplementarySubLocality) {
                    [response setObject:shippingContact.supplementarySubLocality forKey:@"shippingSupplementarySubLocality"];
                }
            }

            if (shippingContact.postalAddress) {

                if (shippingContact.postalAddress.street) {
                    [response setObject:shippingContact.postalAddress.street forKey:@"shippingAddressStreet"];
                }

                if (shippingContact.postalAddress.city) {
                    [response setObject:shippingContact.postalAddress.city forKey:@"shippingAddressCity"];
                }

                if (shippingContact.postalAddress.state) {
                    [response setObject:shippingContact.postalAddress.state forKey:@"shippingAddressState"];
                }

                if (shippingContact.postalAddress.postalCode) {
                    [response setObject:shippingContact.postalAddress.postalCode forKey:@"shippingPostalCode"];
                }

                if (shippingContact.postalAddress.country) {
                    [response setObject:shippingContact.postalAddress.country forKey:@"shippingCountry"];
                }

                if (shippingContact.postalAddress.ISOCountryCode) {
                    [response setObject:shippingContact.postalAddress.ISOCountryCode forKey:@"shippingISOCountryCode"];
                }

            }
        }


    } else if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){8, 0, 0}]) {

        ABRecordRef billingAddress = payment.billingAddress;
        if (billingAddress) {
            //[self applyABRecordShippingAddress:billingAddress forDictionary:response];
        }

        ABRecordRef shippingAddress = payment.shippingAddress;
        if (shippingAddress) {
            [self applyABRecordShippingAddress:shippingAddress forDictionary:response];
        }

    }


    return response;
}

- (PKShippingMethod *)shippingMethodWithIdentifier:(NSString *)idenfifier detail:(NSString *)detail label:(NSString *)label amount:(NSDecimalNumber *)amount
{
    PKShippingMethod *shippingMethod = [PKShippingMethod new];
    shippingMethod.identifier = idenfifier;
    shippingMethod.detail = detail;
    shippingMethod.amount = amount;
    shippingMethod.label = label;

    return shippingMethod;
}

- (NSDecimalNumber *)totalAmount {
    NSDecimalNumber *total = [[NSDecimalNumber alloc] initWithDouble:0.0];
    for (PKPaymentSummaryItem *item in self.paymentRequest.paymentSummaryItems) {
        total = [total decimalNumberByAdding:item.amount];
    }
    return total;
}

#pragma mark - Confirm Controller Actions

- (void)showConfirm:(double)total command:(CDVInvokedUrlCommand *)command {
    self.paymentCommand = command;

    SAPConfirmViewController *controller = [[SAPConfirmViewController alloc] initWithTotal:total];
    controller.delegate = self;
    self.confirmViewController = controller;

    __block UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
    __weak CDVApplePay* weakSelf = self;

    // Run later to avoid the "took a long time" log message.
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.viewController presentViewController:navController animated:YES completion:nil];
    });
}

- (void)hideConfirm {
    if (self.confirmViewController == nil) {
        NSLog(@"Tried to hide controller after it was closed");
        return;
    }

    __weak CDVApplePay* weakSelf = self;

    // Run later to avoid the "took a long time" log message.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.confirmViewController != nil) {
            [weakSelf.viewController dismissViewControllerAnimated:YES completion:nil];
            weakSelf.confirmViewController = nil;
            weakSelf.paymentCommand = nil;
            weakSelf.paymentRequest = nil;
            weakSelf.redirectContext = nil;
        }
    });
}

#pragma mark - PKPaymentAuthorizationViewControllerDelegate

- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller
{
    NSLog(@"paymentAuthorizationViewControllerDidFinish");
    [self.confirmViewController dismissViewControllerAnimated:YES completion:^{
        [self hideConfirm];
    }];

    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:NO];
    [self.commandDelegate sendPluginResult:result callbackId:self.paymentCallbackId];
}

- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                       didAuthorizePayment:(PKPayment *)payment
                                completion:(void (^)(PKPaymentAuthorizationStatus status))completion
{
    NSLog(@"CDVApplePay: didAuthorizePayment");

    __weak CDVApplePay *weakSelf = self;

    void(^handleError)(NSString*) = ^void(NSString *message) {
        [weakSelf hideConfirm];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        [weakSelf.commandDelegate sendPluginResult:result callbackId:weakSelf.paymentCallbackId];
    };

    [[STPAPIClient sharedClient] createTokenWithPayment:payment
         completion:^(STPToken * _Nullable token, NSError * _Nullable error) {
             NSMutableDictionary* createIntentDict = [NSMutableDictionary dictionary];
             NSLog(@"Stripe token == %@", token.tokenId);
             if (token) {
                 createIntentDict[@"amount"] = [NSString stringWithFormat:@"%f", [weakSelf totalAmount].doubleValue];
                 createIntentDict[@"currency"] = weakSelf.paymentRequest.currencyCode;

                 STPPaymentMethodCardParams *cardParams = [STPPaymentMethodCardParams new];
                 cardParams.token = token.tokenId;
                 STPPaymentMethodParams *paymentMethodParams = [STPPaymentMethodParams paramsWithCard:cardParams billingDetails:nil metadata:nil];

                 [[STPAPIClient sharedClient] createPaymentMethodWithParams:paymentMethodParams completion:^(STPPaymentMethod * __nullable paymentMethod, NSError * __nullable error){
                     if (paymentMethod != nil) {
                         createIntentDict[@"paymentMethod"] = paymentMethod.stripeId;
                         NSLog(@"createIntentDict = %@", createIntentDict);
                         CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:createIntentDict];
                         [weakSelf.commandDelegate sendPluginResult:result callbackId:weakSelf.paymentCallbackId];
                     } else {
                         NSString *errorMessage = error.localizedDescription;
                         if (errorMessage == nil) {
                             errorMessage = @"Could not create payment method";
                         }
                         handleError(errorMessage);
                     }
                 }];
             } else {
                 handleError(@"Empty Stripe token");
             }
         }];

    if (completion) {
        self.paymentAuthorizationBlock = completion;
    }
}

#pragma mark - SAPConfirmViewControllerDelegate

- (void)SAPConfirmViewControllerDidCancel:(SAPConfirmViewController *)controller {
    [self hideConfirm];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:NO];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.paymentCommand.callbackId];
}

- (void)SAPConfirmViewControllerDidFail:(SAPConfirmViewController *)controller error:(NSError *)error {
    [self hideConfirm];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.paymentCommand.callbackId];
}

- (void)SAPConfirmViewControllerDidConfirm:(SAPConfirmViewController *)controller {
    [self makePaymentRequest:self.paymentCommand];
}

@end
