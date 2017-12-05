//
//  RCTContactsWrapper.m
//  RCTContactsWrapper
//
//  Created by Oliver Jacobs on 15/06/2016.
//  Copyright © 2016 Facebook. All rights reserved.
//

@import Foundation;
#import "RCTContactsWrapper.h"
@interface RCTContactsWrapper()

@property(nonatomic, retain) RCTPromiseResolveBlock _resolve;
@property(nonatomic, retain) RCTPromiseRejectBlock _reject;

@end


@implementation RCTContactsWrapper

int _requestCode;
const int REQUEST_CONTACT = 1;
const int REQUEST_EMAIL = 2;


RCT_EXPORT_MODULE(ContactsWrapper);

/* Get basic contact data as JS object */
RCT_EXPORT_METHOD(getContact:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    self._resolve = resolve;
    self._reject = reject;
    _requestCode = REQUEST_CONTACT;
    
    [self launchContacts];
    
    
}

/* Get ontact email as string */
RCT_EXPORT_METHOD(getEmail:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    self._resolve = resolve;
    self._reject = reject;
    _requestCode = REQUEST_EMAIL;
    
    [self launchContacts];
    
    
}


/**
 Launch the contacts UI
 */
-(void) launchContacts {
    
    UIViewController *picker;
    picker = [[CNContactPickerViewController alloc] init];
    ((CNContactPickerViewController *)picker).delegate = self;
    
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
    
    //Launch Contact Picker or Address Book View Controller
    UIViewController *root = [[[UIApplication sharedApplication] delegate] window].rootViewController;
    
    BOOL modalPresent = (BOOL) (root.presentedViewController);
    if (modalPresent) {
        UIViewController *parent = root.presentedViewController;
        [parent presentViewController:picker animated:YES completion:nil];
    } else {
        [root presentViewController:picker animated:YES completion:nil];
    }
}


#pragma mark - RN Promise Events

- (void)pickerCancelled {
    self._reject(@"E_CONTACT_CANCELLED", @"Cancelled", nil);
}


- (void)pickerError {
    self._reject(@"E_CONTACT_EXCEPTION", @"Unknown Error", nil);
}

- (void)pickerNoEmail {
    self._reject(@"E_CONTACT_NO_EMAIL", @"No email found for contact", nil);
}

-(void)emailPicked:(NSString *)email {
    self._resolve(email);
}


-(void)contactPicked:(NSDictionary *)contactData {
    self._resolve(contactData);
}


#pragma mark - Shared functions


- (NSMutableDictionary *) emptyContactDict {
    return [[NSMutableDictionary alloc] initWithObjects:@[@"", @"", @"", @""] forKeys:@[@"name", @"phones", @"emails", @"postcodes"]];
}

/**
 Return full name as single string from first last and middle name strings, which may be empty
 */
-(NSString *) getFullNameForFirst:(NSString *)fName middle:(NSString *)mName last:(NSString *)lName {
    //Check whether to include middle name or not
    NSArray *names = (mName.length > 0) ? [NSArray arrayWithObjects:fName, mName, lName, nil] : [NSArray arrayWithObjects:fName, lName, nil];;
    return [names componentsJoinedByString:@" "];
}



#pragma mark - Event handlers - iOS 9+
- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact {
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
    switch(_requestCode){
        case REQUEST_CONTACT:
        {
            /* Return NSDictionary ans JS Object to RN, containing basic contact data
             This is a starting point, in future more fields should be added, as required.
             This could also be extended to return arrays of phone numbers, email addresses etc. instead of jsut first found
             */
            NSMutableDictionary *contactData = [self emptyContactDict];
            
            NSString *fullName = [self getFullNameForFirst:contact.givenName middle:contact.middleName last:contact.familyName ];
            NSArray *phoneNos = contact.phoneNumbers;
            NSArray *emailAddresses = contact.emailAddresses;
            NSArray *postalAddresses = contact.postalAddresses;
            
            //NSLog(@"CONTACT %@: ", contact);
            
            //Return full name
            [contactData setValue:fullName forKey:@"name"];
            
            //Return array of phone numbers
            if([phoneNos count] > 0) {
                NSMutableArray *phoneData = [[NSMutableArray alloc] init];
                
                for (int i = 0; i < [phoneNos count]; i++) {
                    NSMutableDictionary *phoneEntry = [[NSMutableDictionary alloc] init];
                    CNPhoneNumber *phone = ((CNLabeledValue *)phoneNos[i]).value;
                    NSString *label = ((CNLabeledValue *)phoneNos[i]).label;
                    label = [CNLabeledValue localizedStringForLabel:label];
                    
                    [phoneEntry setValue:phone.stringValue forKey:@"phone"];
                    [phoneEntry setValue:label forKey:@"phoneType"];
                    [phoneData addObject:phoneEntry];
                }
                
                [contactData setValue:phoneData forKey:@"phones"];
            }
            
            //Return array of email address
            if([emailAddresses count] > 0) {
                NSMutableArray *emailData = [[NSMutableArray alloc] init];
                
                for (int i = 0; i < [emailAddresses count]; i++) {
                    NSMutableDictionary *emailEntry = [[NSMutableDictionary alloc] init];
                    CNLabeledValue *email = ((CNLabeledValue *)emailAddresses[i]).value;
                    NSString *label = ((CNLabeledValue *)emailAddresses[i]).label;
                    label = [CNLabeledValue localizedStringForLabel:label];
                    
                    [emailEntry setValue:email forKey:@"email"];
                    [emailEntry setValue:label forKey:@"emailType"];
                    [emailData addObject:emailEntry];
                }
                
                [contactData setValue:emailData forKey:@"emails"];
            }
            
            //Return array of postcodes
            if([postalAddresses count] > 0) {
                NSMutableArray *postalData = [[NSMutableArray alloc] init];
                
                for(int i = 0; i < [postalAddresses count]; i++) {
                    NSMutableDictionary *postalEntry = [[NSMutableDictionary alloc] init];
                    CNLabeledValue *value = ((CNLabeledValue *)postalAddresses[i]).value;
                    
                    NSString *postcode = ((CNPostalAddress *)value).postalCode;
                    
                    if([postcode length] != 0) {
                        NSString *label = ((CNLabeledValue *)postalAddresses[i]).label;
                        label = [CNLabeledValue localizedStringForLabel:label];
                        
                        [postalEntry setValue:postcode forKey:@"postcode"];
                        [postalEntry setValue:label forKey:@"postcodeType"];
                        [postalData addObject:postalEntry];
                    }
                }
                
                [contactData setValue:postalData forKey:@"postcodes"];
            }
            
            [self contactPicked:contactData];
        }
            break;
        case REQUEST_EMAIL :
        {
            /* Return Only email address as string */
            if([contact.emailAddresses count] < 1) {
                [self pickerNoEmail];
                return;
            }
            
            CNLabeledValue *email = contact.emailAddresses[0].value;
            [self emailPicked:email];
        }
            break;
        default:
            //Should never happen, but just in case, reject promise
            [self pickerError];
            break;
    }
}


- (void)contactPickerDidCancel:(CNContactPickerViewController *)picker {
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    [self pickerCancelled];
}

@end

