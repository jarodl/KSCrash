//
//  KSCrashReportFilterAppleFmt.m
//
//  Created by Karl Stenerud on 12-02-24.
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


#import "KSCrashReportFilterAppleFmt.h"


#import <mach/machine.h>

#import "ARCSafe_MemMgmt.h"
#import "RFC3339DateTool.h"


#if defined(__LP64__)
    #define TRACE_FMT            @"%-4d%-31s 0x%016llx %@ + %llu\n"
    #define TRACE_SIDEBYSIDE_FMT @"%-4d%-31s 0x%016llx %llx + %llu (%@ + %llu)\n"
    #define POINTER_FMT          @"0x%016llx"
    #define POINTER_SHORT_FMT    @"0x%llx"
    #define POINTER_RJ_FMT       @"%#18llx"
#else
    #define TRACE_FMT            @"%-4d%-31s 0x%08lx %@ + %lu\n"
    #define TRACE_SIDEBYSIDE_FMT @"%-4d%-31s 0x%08lx 0x%lx + %lu (%@ + %lu)\n"
    #define POINTER_FMT          @"0x%08lx"
    #define POINTER_SHORT_FMT    @"0x%lx"
    #define POINTER_RJ_FMT       @"%#10lx"
#endif


@interface KSCrashReportFilterAppleFmt ()

@property(nonatomic,readwrite,assign) KSAppleReportStyle reportStyle;

/** Convert a crash report to Apple format.
 *
 * @param JSONReport The crash report.
 *
 * @param reportStyle The style of report to generate.
 *
 * @return The converted crash report.
 */
- (NSString*) toAppleFormat:(NSDictionary*) JSONReport;

/** Determine the major CPU type.
 *
 * @param CPUArch The CPU architecture name.
 *
 * @return the major CPU type.
 */
- (NSString*) CPUType:(NSString*) CPUArch;

/** Determine the CPU architecture based on major/minor CPU architecture codes.
 *
 * @param majorCode The major part of the code.
 *
 * @param minorCode The minor part of the code.
 *
 * @return The CPU architecture.
 */
- (NSString*) CPUArchForMajor:(int) majorCode minor:(int) minorCode;

/** Append a converted backtrace to a string.
 *
 * @param backtrace The backtrace to convert.
 *
 * @param reportStyle The style of report being generated.
 *
 * @param mainExecutableName Name of the app executable.
 *
 * @param string The string to append to.
 */
- (void) appendBacktrace:(NSArray*) backtrace
             reportStyle:(KSAppleReportStyle) reportStyle
      mainExecutableName:(NSString*) mainExecutableName
         toMutableString:(NSMutableString*) string;

/** Take a UUID string and strip out all the dashes.
 *
 * @param uuid the UUID.
 *
 * @return the UUID in compact form.
 */
- (NSString*) toCompactUUID:(NSString*) uuid;

@end


@implementation KSCrashReportFilterAppleFmt

@synthesize reportStyle = _reportStyle;

/** Date formatter for Apple date format in crash reports. */
NSDateFormatter* g_dateFormatter;

/** Printing order for registers. */
NSDictionary* g_registerOrders;

+ (void) initialize
{
    g_dateFormatter = [[NSDateFormatter alloc] init];
    [g_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS ZZZ"];
    
    NSArray* armOrder = [NSArray arrayWithObjects:
                         @"r0", @"r1", @"r2", @"r3", @"r4", @"r5", @"r6", @"r7",
                         @"r8", @"r9", @"r10", @"r11", @"ip",
                         @"sp", @"lr", @"pc", @"cpsr",
                         nil];
    
    NSArray* x86Order = [NSArray arrayWithObjects:
                         @"eax", @"ebx", @"ecx", @"edx",
                         @"edi", @"esi",
                         @"ebp", @"esp", @"ss",
                         @"eflags", @"eip",
                         @"cs", @"ds", @"es", @"fs", @"gs",
                         nil];
    
    NSArray* x86_64Order = [NSArray arrayWithObjects:
                            @"rax", @"rbx", @"rcx", @"rdx",
                            @"rdi", @"rsi",
                            @"rbp", @"rsp",
                            @"r8", @"r9", @"r10", @"r11", @"r12", @"r13",
                            @"r14", @"r15",
                            @"rip", @"rflags",
                            @"cs", @"fs", @"gs",
                            nil];
    
    g_registerOrders = [[NSDictionary alloc] initWithObjectsAndKeys:
                        armOrder, @"arm",
                        armOrder, @"armv6",
                        armOrder, @"armv7",
                        x86Order, @"x86",
                        x86Order, @"i386",
                        x86Order, @"i486",
                        x86Order, @"i686",
                        x86_64Order, @"x86_64",
                        nil];
}

+ (KSCrashReportFilterAppleFmt*) filterWithReportStyle:(KSAppleReportStyle) reportStyle
{
    return as_autorelease([[self alloc] initWithReportStyle:reportStyle]);
}

- (id) initWithReportStyle:(KSAppleReportStyle) reportStyle
{
    if((self = [super init]))
    {
        self.reportStyle = reportStyle;
    }
    return self;
}

- (void) filterReports:(NSArray*) reports
          onCompletion:(KSCrashReportFilterCompletion) onCompletion
{
    NSMutableArray* filteredReports = [NSMutableArray arrayWithCapacity:[reports count]];
    for(NSDictionary* report in reports)
    {
        [filteredReports addObject:[self toAppleFormat:report]];
    }

    onCompletion(filteredReports, YES, nil);
}

- (NSString*) CPUType:(NSString*) CPUArch
{
    if([CPUArch rangeOfString:@"arm"].location == 0)
    {
        return @"ARM";
    }
    if([CPUArch isEqualToString:@"i486"])
    {
        return @"X86";
    }
    return @"Unknown";
}

- (NSString*) CPUArchForMajor:(int) majorCode minor:(int) minorCode
{
    switch(majorCode)
    {
        case CPU_TYPE_ARM:
        {
            switch (minorCode)
            {
                case CPU_SUBTYPE_ARM_V6:
                    return @"armv6";
                case CPU_SUBTYPE_ARM_V7:
                    return @"armv7";
                default:
                    return @"arm";
            }
            break;
        }
        case CPU_TYPE_X86:
            return @"x86";
        case CPU_TYPE_X86_64:
            return @"x86_64";
    }
    return [NSString stringWithFormat:@"unknown(%d,%d)", majorCode, minorCode];
}

- (void) appendBacktrace:(NSArray*) backtrace
             reportStyle:(KSAppleReportStyle) reportStyle
      mainExecutableName:(NSString*) mainExecutableName
         toMutableString:(NSMutableString*) string
{
    NSUInteger traceNum = 0;
    for(NSDictionary* trace in backtrace)
    {
        uintptr_t pc = (uintptr_t)[[trace objectForKey:@"instruction_addr"] longLongValue];
        uintptr_t objAddr = (uintptr_t)[[trace objectForKey:@"object_addr"] longLongValue];
        NSString* objName = [[trace objectForKey:@"object_name"] lastPathComponent];
        uintptr_t symAddr = (uintptr_t)[[trace objectForKey:@"symbol_addr"] longLongValue];
        NSString* symName = [trace objectForKey:@"symbol_name"];
        uintptr_t offset = pc - symAddr;
        bool isMainExecutable = [objName isEqualToString:mainExecutableName];
        bool symNameIsValid = [symName isKindOfClass:[NSString class]];
        bool symbolicate = reportStyle != KSAppleReportStyleUnsymbolicated && symNameIsValid;
        
        if(reportStyle == KSAppleReportStylePartiallySymbolicated && isMainExecutable)
        {
            symbolicate = NO;
        }
        
        if(![objName isKindOfClass:[NSString class]])
        {
            objName = [NSString stringWithFormat:POINTER_FMT, objAddr];
        }
        
        if(!symbolicate)
        {
            symName = [NSString stringWithFormat:POINTER_SHORT_FMT, symAddr];
            offset = pc - objAddr;
        }
        
        if(reportStyle == KSAppleReportStyleSymbolicatedSideBySide &&
           isMainExecutable && symbolicate)
        {
            [string appendFormat:TRACE_SIDEBYSIDE_FMT,
             traceNum,
             [objName UTF8String],
             pc,
             symAddr,
             pc - objAddr,
             symName,
             offset];
        }
        else
        {
            [string appendFormat:TRACE_FMT,
             traceNum,
             [objName UTF8String],
             pc,
             symName,
             offset];
        }
        traceNum++;
    }
}

- (NSString*) toCompactUUID:(NSString*) uuid
{
    return [[uuid lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
}

- (NSString*) toAppleFormat:(NSDictionary*) JSONReport
{
    NSDictionary* systemInfo = [JSONReport objectForKey:@"system"];
    NSDictionary* crashInfo = [JSONReport objectForKey:@"crash"];
    NSDictionary* errorInfo = [crashInfo objectForKey:@"error"];
    NSArray* binaryImages = [crashInfo objectForKey:@"binary_images"];
    NSArray* threads = [crashInfo objectForKey:@"threads"];
    NSDictionary* exception = [errorInfo objectForKey:@"nsexception"];
    NSString* cpuArch = [systemInfo objectForKey:@"cpu_arch"];
    NSString* cpuArchType = [self CPUType:cpuArch];
    
    NSDate* crashTime = [RFC3339DateTool dateFromString:[JSONReport objectForKey:@"timestamp"]];
    NSString* executablePath = [systemInfo objectForKey:@"CFBundleExecutablePath"];
    NSString* executableName = [executablePath lastPathComponent];
    
    NSMutableString* str = [NSMutableString string];
    [str appendFormat:@"Incident Identifier: %@\n", [JSONReport objectForKey:@"crash_id"]];
    [str appendFormat:@"CrashReporter Key:   %@\n", [systemInfo objectForKey:@"device_app_hash"]];
    [str appendFormat:@"Hardware Model:      %@\n", [systemInfo objectForKey:@"machine"]];
    [str appendFormat:@"Process:         %@ [%@]\n",
     [systemInfo objectForKey:@"process_name"],
     [systemInfo objectForKey:@"process_id"]];
    [str appendFormat:@"Path:            %@\n", executablePath];
    [str appendFormat:@"Identifier:      %@\n", [systemInfo objectForKey:@"CFBundleIdentifier"]];
    [str appendFormat:@"Version:         %@\n", [systemInfo objectForKey:@"CFBundleVersion"]];
    [str appendFormat:@"Code Type:       %@\n", cpuArchType];
    [str appendFormat:@"Parent Process:  %@ [%@]\n",
     [systemInfo objectForKey:@"parent_process_name"],
     [systemInfo objectForKey:@"parent_process_id"]];
    [str appendFormat:@"\n"];
    [str appendFormat:@"Date/Time:       %@\n", [g_dateFormatter stringFromDate:crashTime]];
    [str appendFormat:@"OS Version:      %@ %@ (%@)\n",
     [systemInfo objectForKey:@"system_name"],
     [systemInfo objectForKey:@"system_version"],
     [systemInfo objectForKey:@"os_version"]];
    [str appendFormat:@"Report Version:  104\n"];
    
    [str appendFormat:@"\n"];
    [str appendFormat:@"Exception Type:  %@ (%@)\n",
     [errorInfo objectForKey:@"mach_exception"],
     [errorInfo objectForKey:@"signal_name"]];
    [str appendFormat:@"Exception Codes: %@ at " POINTER_FMT @"\n",
     [errorInfo objectForKey:@"mach_code_name"],
     (uintptr_t)[[errorInfo objectForKey:@"address"] longLongValue]];
    
    NSUInteger threadNum = 0;
    for(NSDictionary* thread in threads)
    {
        if([[thread objectForKey:@"crashed"] boolValue])
        {
            [str appendFormat:@"Crashed Thread:  %d\n", threadNum];
        }
        threadNum++;
    }    
    
    if(exception != nil)
    {
        [str appendFormat:@"\nApplication Specific Information:\n"];
        [str appendFormat:@"*** Terminating app due to uncaught exception '%@', reason: '%@'\n\n",
         [errorInfo objectForKey:@"nsexception_name"],
         [errorInfo objectForKey:@"nsexception_reason"]];
        [str appendFormat:@"Last Exception Backtrace:\n"];
        [self appendBacktrace:[exception objectForKey:@"backtrace"]
                  reportStyle:self.reportStyle
           mainExecutableName:executableName
              toMutableString:str];
    }
    
    int crashedThreadNum = -1;
    
    threadNum = 0;
    for(NSDictionary* thread in threads)
    {
        [str appendFormat:@"\n"];
        BOOL crashed = [[thread objectForKey:@"crashed"] boolValue];
        NSString* name = [thread objectForKey:@"name"];
        NSString* queueName = [thread objectForKey:@"dispatch_queue"];
        
        if(name != nil)
        {
            [str appendFormat:@"Thread %d name:  %@\n", threadNum, name];
        }
        else if(queueName != nil)
        {
            [str appendFormat:@"Thread %d name:  Dispatch queue: %@\n", threadNum, queueName];
        }
        
        if(crashed)
        {
            [str appendFormat:@"Thread %d Crashed:\n", threadNum];
            crashedThreadNum = (int)threadNum;
        }
        else
        {
            [str appendFormat:@"Thread %d:\n", threadNum];
        }
        
        [self appendBacktrace:[thread objectForKey:@"backtrace"]
                  reportStyle:self.reportStyle
           mainExecutableName:executableName
              toMutableString:str];
        
        threadNum++;
    }
    
    if(crashedThreadNum >= 0)
    {
        NSDictionary* thread = [threads objectAtIndex:(NSUInteger)crashedThreadNum];
        [str appendFormat:@"\nThread %d crashed with %@ Thread State:\n",
         crashedThreadNum, cpuArchType];
        NSDictionary* registers = [thread objectForKey:@"registers"];
        NSArray* regOrder = [g_registerOrders objectForKey:cpuArch];
        if(regOrder == nil)
        {
            regOrder = [[registers allKeys] sortedArrayUsingSelector:@selector(compare:)];
        }
        NSUInteger numRegisters = [regOrder count];
        NSUInteger i = 0;
        while(i < numRegisters)
        {
            NSUInteger nextBreak = i + 4;
            if(nextBreak > numRegisters)
            {
                nextBreak = numRegisters;
            }
            for(;i < nextBreak; i++)
            {
                NSString* regName = [regOrder objectAtIndex:i];
                uintptr_t addr = (uintptr_t)[[registers objectForKey:regName] longLongValue];
                [str appendFormat:@"%6s: " POINTER_FMT @" ",
                 [regName cStringUsingEncoding:NSUTF8StringEncoding],
                 addr];
            }
            [str appendString:@"\n"];
        }
    }
    
    [str appendString:@"\nBinary Images:\n"];
    NSMutableArray* images = [NSMutableArray arrayWithArray:binaryImages];
    [images sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2)
     {
         NSNumber* num1 = [(NSDictionary*)obj1 objectForKey:@"image_addr"];
         NSNumber* num2 = [(NSDictionary*)obj2 objectForKey:@"image_addr"];
         return [num1 compare:num2];
     }];
    for(NSDictionary* image in images)
    {
        int cpuType = [[image objectForKey:@"cpu_type"] intValue];
        int cpuSubtype = [[image objectForKey:@"cpu_subtype"] intValue];
        uintptr_t imageAddr = (uintptr_t)[[image objectForKey:@"image_addr"] longLongValue];
        uintptr_t imageSize = (uintptr_t)[[image objectForKey:@"image_size"] longLongValue];
        NSString* path = [image objectForKey:@"name"];
        NSString* name = [path lastPathComponent];
        NSString* uuid = [self toCompactUUID:[image objectForKey:@"uuid"]];
        NSString* isBaseImage = [executablePath isEqualToString:path] ? @"+" : @" ";
        
        [str appendFormat:POINTER_RJ_FMT @" - " POINTER_RJ_FMT @" %@%@ %@  <%@> %@\n",
         imageAddr,
         imageAddr + imageSize - 1,
         isBaseImage,
         name,
         [self CPUArchForMajor:cpuType minor:cpuSubtype],
         uuid,
         path];
    }
    
    return str;
}

@end
