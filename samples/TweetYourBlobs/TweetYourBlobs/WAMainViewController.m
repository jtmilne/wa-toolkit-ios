/*
 Copyright 2010 Microsoft Corp
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "WAMainViewController.h"
#import "WAKeychainController.h"
#import "WABitlyHandler.h"
#import "WABlobTweet.h"
#import "WABitlyCredential.h"
#import "WALocationHandler.h"
#import "WALoginHandler.h"
#import "WABitlyResponse.h"
#import <Twitter/Twitter.h>

typedef enum {
    kTextFieldContainer = 0,
    kTextFieldBlob
} TextFieldTypes;

typedef enum {
    kTableCellContainer = 0,
    kTableCellMakePublic,
    kTableCellBlob,
    kTableCellIncludeLocation
} TableCellTypes;

typedef enum { 
    kButtonIndexDone = 1,
    kButtonIndexCancel
} ButtonIndexTypes;

typedef enum {
    kButtonCamera = 0,
    kButtonExisting,
    kButtonCancel
} ActionButtonIndexs;

@interface WAMainViewController()

- (void)retrieveBitlyInformation;
- (void)postToBlobStorage;
- (void)unlockView;
- (void)lockView;
- (void)displayAlert:(NSString *)message;
- (void)tweet;

@end

@implementation WAMainViewController

@synthesize containerNameTextField = _containerNameTextField;
@synthesize blobNameTextField = _blobNameTextField;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (_blobTweet == nil) {
        _blobTweet = [[WABlobTweet alloc] init];
    }
    
    if (_bitlyCredential == nil) {
        _bitlyCredential = [[WABitlyCredential alloc] init];
    }
    
    if (_locationHandler == nil) {
        _locationHandler = [[WALocationHandler alloc] init];
        _locationHandler.delegate = self;
        [_locationHandler startUpdatingCurrentLocation];
    }
    
    if (_authenticationCredential == nil) {
        WALoginHandler *loginContoller = [[WALoginHandler alloc] initWithStoryBoard:self.storyboard navigationController:self.navigationController];
        [loginContoller login:^(WAAuthenticationCredential *authenticationCredential) {
            _authenticationCredential = authenticationCredential;
            [self.containerNameTextField becomeFirstResponder];
        }];
    }
    
    if (_HUD == nil) {
        _HUD = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
        [self.navigationController.view addSubview:_HUD];
        _HUD.labelText = @"Uploading picture";
    }
    
    self.containerNameTextField.text = _blobTweet.containerName;
}

- (void)viewDidUnload
{
    [self setContainerNameTextField:nil];
    [self setBlobNameTextField:nil];
    [_HUD removeFromSuperview];
    _HUD = nil;
    
    [super viewDidUnload];
}


#pragma mark - UITableViewDelegate methods

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *customView = [[UIView alloc] initWithFrame:CGRectMake(10, 3, tableView.bounds.size.width - 10, 40)];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    switch (section) {
        case 0:
            label.text = @"Container";
            break;
        case 1:
            label.text = @"Blob";
        default:
            break;
    }
    label.textColor = [UIColor whiteColor];
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont boldSystemFontOfSize:18];
    label.frame = CGRectMake(20, 0,customView.bounds.size.width - 20, 40);
    [customView addSubview:label];
    return customView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 40;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row == 0) {
        return;
    }
    
    BOOL checked = NO;
    
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if (cell.accessoryType == UITableViewCellAccessoryCheckmark) {
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        checked = YES;
    }
    
    switch (cell.tag) {
        case kTableCellMakePublic:
            _blobTweet.makeContainerPublic = checked;
            break;
            
        case kTableCellIncludeLocation:
            _blobTweet.includeLocationData = checked;
            break;
            
        default:
            break;
    }
}

#pragma mark - UIImagePickerControllerDelegate methods

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)selectedImage editingInfo:(NSDictionary *)editingInfo
{
    _blobTweet.image = selectedImage;
    self.navigationItem.leftBarButtonItem.enabled = [_blobTweet isValid];
    
    [self dismissModalViewControllerAnimated:YES];   
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
	[self dismissModalViewControllerAnimated:YES];
}

#pragma mark - UIActionSheetDelegate Methods

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
	imagePicker.delegate = self;
	
	if (buttonIndex == kButtonCamera) {
		imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
	}
    
	[self presentModalViewController:imagePicker animated:YES];
}

#pragma mark - UITextFieldDelegate methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    self.navigationItem.leftBarButtonItem.enabled = [_blobTweet isValid];
    
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    switch (textField.tag) {
        case kTextFieldContainer:
            _blobTweet.containerName = textField.text;
            break;
            
        case kTextFieldBlob:
            _blobTweet.blobName = textField.text;
            break;
            
        default:
            break;
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	
	NSString *newStr = [textField.text stringByReplacingCharactersInRange:range withString:string];
	
	if ([newStr rangeOfString:@"^[A-Za-z][A-Za-z0-9\\-\\_]*" 
                      options:NSRegularExpressionSearch].length == newStr.length) {
		return YES;
	}
    
	return NO;
}

#pragma mark - UIAlertViewDelegate methods

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex 
{
    if (buttonIndex == kButtonIndexDone) {
        UITextField *nameField = [alertView textFieldAtIndex:0];
        UITextField *apiKeyField = [alertView textFieldAtIndex:1];
        [_bitlyCredential saveLogin:nameField.text apiKey:apiKeyField.text];
        
        [self postToBlobStorage];
    } 
}


#pragma mark - WALocationControllerDelegate methods

- (void)locationController:(WALocationHandler *)locationController didSelectLocation:(CLLocationCoordinate2D)location
{
    _blobTweet.location = location;
}

#pragma mark - Action methods

- (IBAction)selectImage:(id)sender 
{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [self actionSheet:nil didDismissWithButtonIndex:1];
        return;
    }
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil 
                                                       delegate:self 
                                              cancelButtonTitle:@"Cancel"
                                         destructiveButtonTitle:nil 
                                              otherButtonTitles:@"Take Photo", @"Choose Existing", nil];
    [sheet showInView:self.view];
}

- (IBAction)tweetBlob:(id)sender 
{
    if (!_bitlyCredential.saved) {
        [self retrieveBitlyInformation];
    } else {
        [self postToBlobStorage];
    }
}

#pragma mark - Private methods

- (void)displayAlert:(NSString *)message
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Tweet Your Blobs"
													message:message
												   delegate:nil 
										  cancelButtonTitle:@"OK"
										  otherButtonTitles:nil];
	[alert show];
}

- (void)unlockView
{
    self.navigationItem.leftBarButtonItem.enabled = YES;
    self.navigationItem.rightBarButtonItem.enabled = YES;
    [_HUD hide:YES];
}

- (void)lockView
{
    self.navigationItem.leftBarButtonItem.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [_HUD show:YES];
}

- (void)retrieveBitlyInformation 
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Setup Bitly Credentials" 
                                                        message:@"Enter your Bitly Crendentials"  
                                                       delegate:self 
                                              cancelButtonTitle:@"Cancel" 
                                              otherButtonTitles:@"Done", nil];
    [alertView setAlertViewStyle:UIAlertViewStyleLoginAndPasswordInput];
    UITextField *nameField = [alertView textFieldAtIndex:0];
    nameField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    nameField.placeholder = @"Name"; 
    UITextField *apiKeyField = [alertView textFieldAtIndex:1]; // Capture the Password text field since there are 2 fields
    apiKeyField.placeholder = @"Api Key";
    [alertView show];
}

- (void)postToBlobStorage
{
    if (_blobTweet.isReadyToTweet) {
        [self tweet];
        return;
    }
    
    [self lockView];
    
    WACloudStorageClient *addContainerClient = [WACloudStorageClient storageClientWithCredential:_authenticationCredential];
    
    WABlobContainer *containerToAdd = [[WABlobContainer alloc] initContainerWithName:_blobTweet.containerName];
    containerToAdd.isPublic = _blobTweet.makeContainerPublic;
    containerToAdd.createIfNotExists = YES;
    [addContainerClient addBlobContainer:containerToAdd withCompletionHandler:^(NSError *error) {
        if (error != nil) {
            [self displayAlert:error.localizedDescription];
            [self unlockView];
            return;
        }
        
        WACloudStorageClient *fetchContainerClient = [WACloudStorageClient storageClientWithCredential:_authenticationCredential];
        [fetchContainerClient fetchBlobContainerNamed:containerToAdd.name withCompletionHandler:^(WABlobContainer *container, NSError *error) {
            if (error != nil) {
                [self displayAlert:error.localizedDescription];
                [self unlockView];
                return;
            }
            
            WABlob *blob = [[WABlob alloc] initBlobWithName:_blobTweet.blobName  URL:nil containerName:container.name];
            blob.contentType = @"image/jpeg";
            blob.contentData = UIImageJPEGRepresentation(_blobTweet.image, 1.0); 
            if (_blobTweet.includeLocationData) {
                [blob setValue:_blobTweet.bingLocation forMetadataKey:@"ContentLocation"];
            }
            [blob setValue:@"image/jpeg" forMetadataKey:@"ImageType"];
            WACloudStorageClient *addBlobClient = [WACloudStorageClient storageClientWithCredential:_authenticationCredential];
            [addBlobClient addBlob:blob toContainer:container withCompletionHandler:^(NSError *error) {
                if (error != nil) {
                    [self displayAlert:error.localizedDescription];
                    [self unlockView];
                    return;
                }
                
                WABlobFetchRequest *request = [WABlobFetchRequest fetchRequestWithContainer:container resultContinuation:nil];
                request.prefix = blob.name;
                WACloudStorageClient *fetchBlobClient = [WACloudStorageClient storageClientWithCredential:_authenticationCredential];
                [fetchBlobClient fetchBlobsWithRequest:request usingCompletionHandler:^(NSArray *blobs, WAResultContinuation *resultContinuation, NSError *error){
                    if (error != nil) {
                        [self displayAlert:error.localizedDescription];
                        [self unlockView];
                        return;
                    }
                    WABlob *blobToShorten = [blobs objectAtIndex:0];
                    WABitlyHandler *bitlyHandler = [[WABitlyHandler alloc] initWithLongURL:blobToShorten.URL username:_bitlyCredential.login apiKey:_bitlyCredential.apiKey];
                    [bitlyHandler shortenUrlWithCompletionHandler:^(WABitlyResponse *response, NSError *error) {
                        if (error != nil) {
                            [_bitlyCredential clear];
                            [self displayAlert:error.localizedDescription];
                            [self unlockView];
                            return;
                        }
                        
                        _blobTweet.shortUrl = response.shortURL;
                        // post to twitter
                        [self tweet];
                        [self unlockView];
                    }];
                    
                }];
            }];
        }];
    }];
}

- (void)tweet
{
    Class tweeterClass = NSClassFromString(@"TWTweetComposeViewController");
    
    // check for Twitter integration
    if(tweeterClass != nil) {   
        // check Twitter accessibility and at least one account is setup
        if([TWTweetComposeViewController canSendTweet]) {
            TWTweetComposeViewController *tweetViewController = [[TWTweetComposeViewController alloc] init];
            [tweetViewController addURL:_blobTweet.shortUrl];
            tweetViewController.completionHandler = ^(TWTweetComposeViewControllerResult result) {
                if(result == TWTweetComposeViewControllerResultDone) {
                    // the user finished composing a tweet
                    [_blobTweet clear];
                    self.navigationItem.leftBarButtonItem.enabled = [_blobTweet isValid];
                    _blobNameTextField.text = @"";
                } else if(result == TWTweetComposeViewControllerResultCancelled) {
                    // the user cancelled composing a tweet
                }
                [self dismissViewControllerAnimated:YES completion:nil];
            };
            
            [self presentViewController:tweetViewController animated:YES completion:nil];
        } else {
            // Twitter is not accessible or the user has not setup an account
            [self displayAlert:@"You can't send a tweet right now, make sure your device has an internet connection and you have at least one Twitter account setup."];
        }
    } else {
        // no Twitter integration could default to third-party Twitter framework
    }
}

@end
