/*
	Copyright (C) 2004 James Duncan Davidson, Nicolas Roard, Quentin Mathe, Christopher Armstrong, Eric Wasylishen

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

#import "UKRunner.h"
#import "UKTest.h"
#import "UKTestHandler.h"

#include <objc/runtime.h>

// NOTE: From EtoileFoundation/Macros.h
#define INVALIDARG_EXCEPTION_TEST(arg, condition) do { \
    if (NO == (condition)) \
    { \
        [NSException raise: NSInvalidArgumentException format: @"For %@, %s " \
            "must respect %s", NSStringFromSelector(_cmd), #arg , #condition]; \
    } \
} while (0);
#define NILARG_EXCEPTION_TEST(arg) do { \
    if (nil == arg) \
    { \
        [NSException raise: NSInvalidArgumentException format: @"For %@, " \
            "%s must not be nil", NSStringFromSelector(_cmd), #arg]; \
    } \
} while (0);

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

@implementation UKRunner
{
	int _testClassesRun;
	int _testMethodsRun;
	BOOL _releasing;
}

#pragma mark - Localization Support

+ (NSString *)localizedString: (NSString *)key
{
	NSBundle *bundle = [NSBundle bundleForClass: [self class]];
	return NSLocalizedStringFromTableInBundle(key, @"UKRunner", bundle, @"");
}

+ (NSString *)displayStringForException: (id)exc
{
	if ([exc isKindOfClass: [NSException class]])
	{
		return [NSString stringWithFormat: @"NSException: %@ %@",
		                                   [exc name], [exc reason]];
	}
	else
	{
		return NSStringFromClass([exc class]);
	}
}

/**
 * For now, we still support -classRegex as an alias to -c.
 *
 * This options read with NSUserDefaults is overwritten by 
 * -parseArgumentsWithCurrentDirectory:. This NSUserDefaults use should probably 
 * be removed at some point.
 */
- (NSString *)stringFromArgumentDomainForKey: (NSString *)key
{
	NSDictionary *argumentDomain = [[NSUserDefaults standardUserDefaults]
	  volatileDomainForName: NSArgumentDomain];
	return argumentDomain[key];
}

- (instancetype)init
{
	self = [super init];
	if (self == nil)
		return nil;

	_classRegex = [self stringFromArgumentDomainForKey: @"c"];
	if (nil == _classRegex)
	{
		_classRegex = [self stringFromArgumentDomainForKey: @"classRegex"];
	}
	_className = [self stringFromArgumentDomainForKey: @"className"];
	_methodRegex = [self stringFromArgumentDomainForKey: @"methodRegex"];
	_methodName = [self stringFromArgumentDomainForKey: @"methodName"];

	return self;
}

#pragma mark - Loading Test Bundles

- (id)loadBundleAtPath: (NSString *)bundlePath
{
	NSBundle *testBundle = [NSBundle bundleWithPath: bundlePath];

	if (testBundle == nil)
	{
		NSLog(@"\n == Test bundle '%@' could not be found ==\n", bundlePath.lastPathComponent);
		return nil;
	}

	if (![bundlePath.pathExtension isEqual: [self testBundleExtension]])
	{
		NSLog(@"\n == Directory '%@' is not a test bundle ==\n", bundlePath.lastPathComponent);
	}

	NSError *error = nil;

	/* For Mac OS X (10.8), the test bundle info.plist must declare a principal
	   class, to prevent +load from instantiating NSApp. */
#ifdef GNUSTEP
	if (![testBundle load])
#else
	if (![testBundle loadAndReturnError: &error])
#endif
	{
		NSLog(@"\n == Test bundle could not be loaded: %@ ==\n", error.description);
		return nil;
	}
	return testBundle;
}

- (NSString *)testBundleExtension
{
	return @"bundle";
}

- (NSArray *)bundlePathsInCurrentDirectory: (NSString *)cwd
{
	NSError *error = nil;
	NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: cwd
	                                                                     error: &error];
	NSAssert(error == nil, [error description]);

	return [files filteredArrayUsingPredicate:
	                [NSPredicate predicateWithFormat: @"pathExtension == %@",
	                                                  [self testBundleExtension]]];
}

- (NSArray *)bundlePathsFromArgumentsAndCurrentDirectory: (NSString *)cwd
{
	NSArray *bundlePaths = [self parseArgumentsWithCurrentDirectory: cwd];
	NSAssert(bundlePaths != nil, @"");
	BOOL hadBundleInArgument = (bundlePaths.count > 0);

	if (hadBundleInArgument)
		return bundlePaths;

	/* If no bundles is specified, then just collect every bundle in this folder */
	return [self bundlePathsInCurrentDirectory: cwd];
}

#pragma mark - Tool Support

+ (int)runTests
{
	NSString *version = [NSBundle bundleForClass: self].infoDictionary[@"CFBundleShortVersionString"];
	int result = 0;

	NSLog(@"UnitKit version %@ (Etoile)", version);

	@autoreleasepool
	{
		UKRunner *runner = [[UKRunner alloc] init];
		NSString *cwd = [NSFileManager defaultManager].currentDirectoryPath;

		for (NSString *bundlePath in [runner bundlePathsFromArgumentsAndCurrentDirectory: cwd])
		{
			[runner runTestsInBundleAtPath: bundlePath
			              currentDirectory: cwd];
		}

		result = [runner reportTestResults];
	}
	return result;
}

/**
 * Don't try to parse options without value e.g. -q with NSUserDefaults, 
 * otherwise the option will be ignored or its value set to the next argument. 
 * For example, the NSArgumentDomain dictionary would be:
 *
 * 'ukrun -q' => { }
 * 'ukrun -q TestBundle.bundle' => { -q = TestBundle.bundle }
 */
- (NSArray *)parseArgumentsWithCurrentDirectory: (NSString *)cwd
{
	NSArray *args = [NSProcessInfo processInfo].arguments;
	NSMutableArray *bundlePaths = [NSMutableArray array];
	BOOL noOptions = (args.count <= 1);
	NSSet *paramOptions = [NSSet setWithObjects:
	                               @"-c",
	                               @"-classRegex",
	                               @"-className",
	                               @"-methodRegex",
	                               @"-methodName",
	                             nil];

	if (noOptions)
		return bundlePaths;

	for (int i = 1; i < args.count; i++)
	{
		NSString *arg = args[i];

		/* We parse all supported options to skip them and process the test 
		   bundle list at the end */
		if ([arg isEqualToString: @"-q"])
		{
			[[UKTestHandler handler] setQuiet: YES];
		}
		else if ([paramOptions containsObject: arg])
		{
			i++;

			if (i >= args.count || [args[i] hasPrefix: @"-"])
			{
				NSLog(@"%@ argument must be followed by a parameter", arg);
				exit(-1);
			}
			NSString *param = args[i];

			if ([arg isEqualToString: @"-c"] || [arg isEqualToString: @"-classRegex"])
			{
				_classRegex = param;
			}
			else if ([arg isEqualToString: @"-className"])
			{
				_className = param;
			}
			else if ([arg isEqualToString: @"-methodRegex"])
			{
				_methodRegex = param;
			}
			else if ([arg isEqualToString: @"-methodName"])
			{
				_methodName = param;
			}
		}
		else
		{
			[bundlePaths addObject: args[i]];
		}
	}
	return bundlePaths;
}

- (void)runTestsInBundleAtPath: (NSString *)bundlePath
              currentDirectory: (NSString *)cwd
{
	bundlePath = bundlePath.stringByExpandingTildeInPath;

	if (!bundlePath.absolutePath)
	{
		bundlePath = [cwd stringByAppendingPathComponent: bundlePath];
		bundlePath = bundlePath.stringByStandardizingPath;
	}

	NSLog(@"Looking for bundle at path: %@", bundlePath);

	@autoreleasepool
	{
		NSBundle *testBundle = [self loadBundleAtPath: bundlePath];

		if (testBundle != nil)
		{
			[self runTestsInBundle: testBundle];
		}
	}
}

#pragma mark - Running Test Method

- (void)internalRunTest: (NSTimer *)timer
{
	NSDictionary *testParameters = timer.userInfo;
	NSString *testMethodName = testParameters[@"TestSelector"];
	SEL testSel = NSSelectorFromString(testMethodName);
	id testObject = testParameters[@"TestObject"];
	Class testClass = testParameters[@"TestClass"];

	// N.B.: On GNUstep, NSTimer ignores exceptions
	// so they wouldn't reach the @catch block in -runTests:onInstance:ofClass:,
	// so we need this @try/@catch block here
	@try
	{
		[testObject performSelector: testSel];
	}
	@catch (NSException *exception)
	{
		[[UKTestHandler handler] reportException: exception
		                                 inClass: testClass
		                                    hint: testMethodName];
	}
}

- (void)runTest: (SEL)testSelector onObject: (id)testObject class: (Class)testClass
{
	NSLog(@"=== [%@ %@] ===", [testObject class], NSStringFromSelector(testSelector));

	NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
	NSDictionary *testParams = @{@"TestObject": testObject,
	                             @"TestSelector": NSStringFromSelector(testSelector),
	                             @"TestClass": testClass};
	NSTimer *runTimer = [NSTimer scheduledTimerWithTimeInterval: 0
	                                                     target: self
	                                                   selector: @selector(internalRunTest:)
	                                                   userInfo: testParams
	                                                    repeats: NO];

	while (runTimer.valid)
	{
		// NOTE: nil, [NSDate date], time intervals such as 0, 0.0000001 or
		// LDBL_EPSILON don't work on GNUstep.
		//
		// 0.000001 was working on GNUstep, but it resulted in freezing
		// when debugging with Valgrind! Using 0.001 fixed that,
		// but it suggests that gnustep-base might be broken
#ifdef GNUSTEP
		NSTimeInterval interval = 0.001;
#else
		NSTimeInterval interval = 0;
#endif
		[runLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: interval]];
	}
}

#pragma mark - Running Tests

- (void)runTests: (NSArray *)testMethods onInstance: (BOOL)instance ofClass: (Class)testClass
{
	for (NSString *testMethodName in testMethods)
	{
		_testMethodsRun++;

		@try
		{
			@autoreleasepool
			{
				[self runTestNamed: testMethodName
				        onInstance: instance
				           ofClass: testClass];
			}
		}
		@catch (NSException *exception)
		{
			id hint = (_releasing ? @"errExceptionOnRelease" : nil);

			[[UKTestHandler handler] reportException: exception
			                                 inClass: testClass
			                                    hint: hint];
		}
		_releasing = NO;
	}
}

- (void)runTestNamed: (NSString *)testMethodName
          onInstance: (BOOL)instance
             ofClass: (Class)testClass
{
	id object = nil;

	// Create the object to test

	if (instance)
	{
		@try
		{
			object = [[testClass alloc] init];
		}
		@catch (NSException *exception)
		{
			[[UKTestHandler handler] reportException: exception
			                                 inClass: testClass
			                                    hint: @"errExceptionOnInit"];
		}

		// N.B.: If -init throws an exception or returns nil, we don't
		// attempt to run any more methods on this class
		if (object == nil)
			return;
	}
	else
	{
		object = testClass;
	}

	// Run the test method

	@try
	{
		SEL testSel = NSSelectorFromString(testMethodName);

		/* This pool makes easier to separate autorelease issues between:
		 - test method
		 - test object configuration due to -init and -dealloc

		 For testing CoreObject, this also ensures all autoreleased
		 objects in relation to a db are deallocated before closing
		 the db connection in -dealloc (see TestCommon.h in CoreObject
		 for details) */
		@autoreleasepool
		{
			[self runTest: testSel onObject: object class: testClass];
		}
	}
	@catch (NSException *exception)
	{
		[[UKTestHandler handler] reportException: exception
		                                 inClass: testClass
		                                    hint: testMethodName];
	}

	// Release the object

	if (instance)
	{
		@try
		{
			_releasing = YES;
			object = nil;
		}
		@catch (NSException *exception)
		{
			// N.B.: With ARC, we usually catch dealloc exception later in the
			// caller, when the enclosing autorelease pool goes away.
			[[UKTestHandler handler] reportException: exception
			                                 inClass: [object class]
			                                    hint: @"errExceptionOnRelease"];
		}
	}
}

- (void)runTestsInClass: (Class)testClass
{
	_testClassesRun++;

	NSArray *testMethods = nil;

	/* Test class methods */

	if (testClass != nil)
	{
		testMethods = [self filterTestMethodNames: UKTestMethodNamesFromClass(objc_getMetaClass(class_getName(testClass)))];
	}
	[self runTests: testMethods onInstance: NO ofClass: testClass];

	/* Test instance methods */

	testMethods = [self filterTestMethodNames: UKTestMethodNamesFromClass(testClass)];
	[self runTests: testMethods onInstance: YES ofClass: testClass];
}

- (NSArray *)filterTestClassNames: (NSArray *)testClassNames
{
	if (nil != _className)
	{
		if ([testClassNames containsObject: _className])
		{
			return @[_className];
		}
		return [NSArray array];
	}

	NSMutableArray *filteredClassNames = [NSMutableArray array];

	for (NSString *testClassName in testClassNames)
	{
		if (_classRegex == nil || [testClassName rangeOfString: _classRegex
		                                               options: NSRegularExpressionSearch].location != NSNotFound)
		{
			[filteredClassNames addObject: testClassName];
		}
	}

	return filteredClassNames;
}

- (NSArray *)filterTestMethodNames: (NSArray *)testMethodNames
{
	if (nil != _methodName)
	{
		if ([testMethodNames containsObject: _methodName])
		{
			return @[_methodName];
		}
		return [NSArray array];
	}

	NSMutableArray *filteredMethodNames = [NSMutableArray array];

	for (NSString *testMethodName in testMethodNames)
	{
		if (_methodRegex == nil || [testMethodName rangeOfString: self.methodRegex
		                                                 options: NSRegularExpressionSearch].location != NSNotFound)
		{
			[filteredMethodNames addObject: testMethodName];
		}
	}

	return filteredMethodNames;
}

- (void)runTestsInBundle: (NSBundle *)bundle
{
	NILARG_EXCEPTION_TEST(bundle);

	[self runTestsWithClassNames: nil
	                    inBundle: bundle
	              principalClass: bundle.principalClass];
}

- (void)runTestsWithClassNames: (NSArray *)testClassNames
                principalClass: (Class)principalClass
{
	[self runTestsWithClassNames: testClassNames
	                    inBundle: [NSBundle mainBundle]
	              principalClass: principalClass];
}

/**
 * We must call UKTestClassNamesFromBundle() after +willRunTestSuite, otherwise 
 * the wrong app object can be created in a UI related test suite on Mac OS X...
 * 
 * On Mac OS X, we have -bundleForClass: that invokes class_respondsToSelector() 
 * which results in +initialize being called, and +[NSWindowBinder initialize] 
 * has the bad idea to use +sharedApplication. 
 * When no app object is available yet, an NSApplication instance will be 
 * created rather than the subclass instance we might want.
 *
 * This is why we don't call UKTestClassNamesFromBundle() in
 * -runTestsInBundle:principalClass:. 
 */
- (void)runTestsWithClassNames: (NSArray *)testClassNames
                      inBundle: (NSBundle *)bundle
                principalClass: (Class)principalClass
{
	NSDate *startDate = [NSDate date];

	if ([principalClass respondsToSelector: @selector(willRunTestSuite)])
	{
		[principalClass willRunTestSuite];
	}

	NSArray *classNames =
	  (testClassNames != nil ? testClassNames : UKTestClassNamesFromBundle(bundle));

	for (NSString *name in [self filterTestClassNames: classNames])
	{
		[self runTestsInClass: NSClassFromString(name)];
	}

	if ([principalClass respondsToSelector: @selector(didRunTestSuite)])
	{
		[principalClass didRunTestSuite];
	}

	NSLog(@"Took %d ms\n", (int)([[NSDate date] timeIntervalSinceDate: startDate] * 1000));
}

#pragma mark - Reporting Test Results

- (int)reportTestResults
{
	int testsPassed = [UKTestHandler handler].testsPassed;
	int testsFailed = [UKTestHandler handler].testsFailed;
	int exceptionsReported = [UKTestHandler handler].exceptionsReported;

	// TODO: May be be extract in -testResultSummary
	NSLog(@"Result: %i classes, %i methods, %i tests, %i failed, %i exceptions",
	      _testClassesRun, _testMethodsRun, (testsPassed + testsFailed), testsFailed, exceptionsReported);

	return (testsFailed == 0 && exceptionsReported == 0 ? 0 : -1);
}

@end

BOOL UKTestClassConformsToProtocol(Class aClass)
{
	Class class = aClass;
	BOOL isTestClass = NO;

	while (class != Nil && !isTestClass)
	{
		isTestClass = class_conformsToProtocol(class, @protocol(UKTest));
		class = class_getSuperclass(class);
	}
	return isTestClass;
}

NSArray *UKTestClassNamesFromBundle(NSBundle *bundle)
{
	NSMutableArray *testClasseNames = [NSMutableArray array];
	int numClasses = objc_getClassList(NULL, 0);

	if (numClasses > 0)
	{
		Class *classes = (Class *)malloc(sizeof(Class) * numClasses);

		objc_getClassList(classes, numClasses);

		for (int i = 0; i < numClasses; i++)
		{
			Class c = classes[i];

			/* Using class_conformsToProtocol() intead of +conformsToProtocol:
			   does not require sending a message to the class. This prevents
			   +initialize being sent to classes that are not explicitly used.

			   Note: +bundleForClass: will initialize test classes on Mac OS X. */
			if (UKTestClassConformsToProtocol(c) && bundle == [NSBundle bundleForClass: c])
			{
				[testClasseNames addObject: NSStringFromClass(c)];
			}
		}
		free(classes);
	}

	return [testClasseNames sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
}


NSArray *UKTestMethodNamesFromClass(Class sourceClass)
{
	NSMutableArray *testMethods = [NSMutableArray array];

	for (Class c = sourceClass; c != Nil; c = class_getSuperclass(c))
	{
		unsigned int methodCount = 0;
		Method *methodList = class_copyMethodList(c, &methodCount);
		Method method = NULL;

		for (int i = 0; i < methodCount; i++)
		{
			method = methodList[i];
			SEL sel = method_getName(method);
			NSString *methodName = NSStringFromSelector(sel);

			if ([methodName hasPrefix: @"test"])
			{
				[testMethods addObject: methodName];
			}
		}
		free(methodList);
	}

	return [testMethods sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
}
