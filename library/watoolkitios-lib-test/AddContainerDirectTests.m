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

#import "AddContainerDirectTests.h"
#import "WAToolkit.h"

@implementation AddContainerDirectTests

#ifdef INTEGRATION_DIRECT

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    WABlobContainer *container = [[[WABlobContainer alloc] initContainerWithName:randomContainerNameString] autorelease];
    [directClient deleteBlobContainer:container withCompletionHandler:^(NSError *error) {
        STAssertNil(error, @"Error returned from deleteBlobContainerNamed: %@",[error localizedDescription]);
        [directDelegate markAsComplete];
    }];
    [directDelegate waitForResponse];
    
    [super tearDown];
}

-(void)testShouldAddContainerWithCompletionHandlerDirect
{   
    WABlobContainer *container = [[[WABlobContainer alloc] initContainerWithName:randomContainerNameString] autorelease];
    [directClient addBlobContainer:container withCompletionHandler:^(NSError *error) {
        STAssertNil(error, @"Error returned from addBlobContainerNamed: %@",[error localizedDescription]);
        [directDelegate markAsComplete];
    }];
    [directDelegate waitForResponse];
    
    WABlobContainerFetchRequest *fetchRequest = [WABlobContainerFetchRequest fetchRequest];
    [directClient fetchBlobContainersWithRequest:fetchRequest usingCompletionHandler:^(NSArray *containers, WAResultContinuation *resultContinuation, NSError *error) {
        __block BOOL foundContainer = NO;
        [containers enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
            WABlobContainer *container = (WABlobContainer*)object;
            if ([container.name isEqualToString:randomContainerNameString]) {
                foundContainer = YES;
                *stop = YES;
            }
        }];
        STAssertTrue(foundContainer, @"Did not find the containers that was just added.");
         
        [directDelegate markAsComplete];
    }];
    [directDelegate waitForResponse];
}

#endif

@end
