//
//  KSCrashReportFilter.h
//
//  Created by Karl Stenerud on 12-02-18.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <Foundation/Foundation.h>

/** Callback for filter operations.
 *
 * @param filteredReports The filtered reports (may be incomplete if "completed"
 *                        is false).
 *
 * @param completed True if filtering completed.
 *                  Can be false due to a non-erroneous condition (such as a
 *                  user cancelling the operation).
 *
 * @param error Non-nil if an error occurred.
 */
typedef void(^KSCrashReportFilterCompletion)(NSArray* filteredReports,
                                             BOOL completed,
                                             NSError* error);

@protocol KSCrashReportFilter <NSObject>

- (void) filterReports:(NSArray*) reports
          onCompletion:(KSCrashReportFilterCompletion) onCompletion;

@end

@protocol KSCrashReportDefaultFilterSet <NSObject>

- (NSArray*) defaultCrashReportFilterSet;

@end


@interface KSCrashReportFilterPassthrough : NSObject <KSCrashReportFilter>

+ (KSCrashReportFilterPassthrough*) filter;

@end


// Combine the results of multiple filters into a master report (dictionary)
@interface KSCrashReportFilterCombine : NSObject <KSCrashReportFilter>

// Each entry can be a filter or an array of filters.
+ (KSCrashReportFilterCombine*) filterWithFiltersAndKeys:(id) firstFilter, ... NS_REQUIRES_NIL_TERMINATION;

- (id) initWithFiltersAndKeys:(id)firstFilter, ... NS_REQUIRES_NIL_TERMINATION;

@end


// Make a pipeline of filters, passing reports through each one.
@interface KSCrashReportFilterPipeline : NSObject <KSCrashReportFilter>

@property(nonatomic,readonly,retain) NSArray* filters;

+ (KSCrashReportFilterPipeline*) filterWithFilters:(id) firstFilter, ... NS_REQUIRES_NIL_TERMINATION;

- (id) initWithFilters:(id) firstFilter, ... NS_REQUIRES_NIL_TERMINATION;

@end


/**
 * Take one object from the report. If key is a string, it will be interpreted
 * as a key path.
 */
@interface KSCrashReportFilterObjectForKey : NSObject <KSCrashReportFilter>

+ (KSCrashReportFilterObjectForKey*) filterWithKey:(id) key;

- (id) initWithKey:(id) key;

@end


// Interprets reports as dictionary of strings and concatenates
@interface KSCrashReportFilterConcatenate : NSObject <KSCrashReportFilter>

+ (KSCrashReportFilterConcatenate*) filterWithSeparatorFmt:(NSString*) separatorFmt
                                                      keys:(id) firstKey, ... NS_REQUIRES_NIL_TERMINATION;

- (id) initWithSeparatorFmt:(NSString*) separatorFmt
                       keys:(id) firstKey, ... NS_REQUIRES_NIL_TERMINATION;

@end


// Interprets reports as dictionaries and passes on a subset of that dictionary
@interface KSCrashReportFilterSubset : NSObject <KSCrashReportFilter>

+ (KSCrashReportFilterSubset*) filterWithKeys:(id) firstKeyPath, ... NS_REQUIRES_NIL_TERMINATION;

- (id) initWithKeys:(id) firstKeyPath, ... NS_REQUIRES_NIL_TERMINATION;

@end
