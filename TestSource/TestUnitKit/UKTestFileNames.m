/*
	Copyright (C) 2004 James Duncan Davidson

	License:  Apache License, Version 2.0  (see LICENSE)
 
	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at
 
	http://www.apache.org/licenses/LICENSE-2.0
 
	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
 
	The use of the Apache License does not indicate that this project is
	affiliated with the Apache Software Foundation.
 */

#import "UKTestFileNames.h"

@implementation UKTestFileNames

- (instancetype)init
{
	self = [super init];
	if (self == nil)
		return nil;

	handler = [UKTestHandler handler];
	handler.delegate = self;
	actualFilename = [[NSString alloc] initWithCString: __FILE__
	                                          encoding: NSUTF8StringEncoding];
	return self;
}

- (void)reportStatus: (BOOL)cond
              inFile: (char *)filename
                line: (int)line
             message: (NSString *)msg
{
	reportedFilename = [[NSString alloc] initWithCString: filename
	                                            encoding: NSUTF8StringEncoding];
}

- (void)testUKPass
{
	UKPass();
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKFail
{
	UKFail();
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKTrue
{
	UKTrue(YES);
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKTrue_Negative
{
	UKTrue(NO);
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKFalse
{
	UKFalse(NO);
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKFalse_Negative
{
	UKFalse(YES);
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKNil
{
	UKNil(nil);
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKNil_Negative
{
	UKNil(@"");
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKNotNil
{
	UKNotNil(@"");
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKNotNil_Negative
{
	UKNotNil(nil);
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKIntsEqual
{
	UKIntsEqual(1, 1);
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKIntsEqual_Negative
{
	UKIntsEqual(1, 2);
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKFloatsEqual
{
	UKFloatsEqual(1.0, 1.0, 0.1);
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKFloatsEqual_Negative
{
	UKFloatsEqual(1.0, 2.0, 0.1);
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKFloatsNotEqual
{
	UKFloatsNotEqual(1.0, 2.0, 0.1);
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKFloatsNotEqual_Negative
{
	UKFloatsNotEqual(1.0, 1.0, 0.1);
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKObjectsEqual
{
	UKObjectsEqual(self, self);
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKObjectsEqual_Negative
{
	UKObjectsEqual(self, @"asdf");
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKObjectsSame
{
	UKObjectsSame(self, self);
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKObjectsSame_Negative
{
	UKObjectsSame(self, @"asdf");
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKStringsEqual
{
	UKStringsEqual(@"a", @"a");
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKStringsEqual_Negative
{
	UKStringsEqual(@"a", @"b");
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKStringContains
{
	UKStringContains(@"Now is the time", @"the time");
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKStringContains_Negative
{
	UKStringContains(@"asdf", @"zzzzz");
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKStringDoesNotContain
{
	UKStringDoesNotContain(@"asdf", @"zzzzz");
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}

- (void)testUKStringDoesNotContain_Negative
{
	UKStringDoesNotContain(@"Now is the time", @"the time");
	handler.delegate = nil;
	UKStringsEqual(actualFilename, reportedFilename);
}


@end
