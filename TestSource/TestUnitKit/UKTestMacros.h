/*
    Copyright (C) 2004 James Duncan Davidson, Michael Milvich

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

#import <Foundation/Foundation.h>
#import <UnitKit/UnitKit.h>

/**
 * Exercise the various values that can be fed through each of the macros. In
 * this test class, we are only concerned about the pass or fail status. We have
 * other classes to test whether or not the line numbers and filenames make it
 * through.
 *
 * Because this class deals with the very heart of the test mechanism, a few of
 * the tests also contain NSAssert statements so that if things go very wrong
 * there will be something to indicate what's going on.
 */
@interface UKTestMacros : NSObject <UKTest>
{
    UKTestHandler *handler;
    BOOL reportedStatus;
}

@end
