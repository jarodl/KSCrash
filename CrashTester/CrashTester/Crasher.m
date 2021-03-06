//
//  Crasher.m
//
//  Created by Karl Stenerud on 12-01-28.
//

#import "Crasher.h"
#import "ARCSafe_MemMgmt.h"

@implementation Crasher

int* g_crasher_null_ptr = NULL;
int g_crasher_denominator = 0;

+ (void) throwException
{
    id data = @"a";
    [data objectAtIndex:0];
}

+ (void) dereferenceBadPointer
{
    char* ptr = (char*)-1;
    *ptr = 1;
}

+ (void) dereferenceNullPointer
{
    *g_crasher_null_ptr = 1;
}

+ (void) useCorruptObject
{
    // From http://landonf.bikemonkey.org/2011/09/14
    
    // Random data
    void* pointers[] = {NULL, NULL, NULL};
    void* randomData[] = {"a","b",pointers,"d","e","f"};
    
    // A corrupted/under-retained/re-used piece of memory
    struct {void* isa;} corruptObj = {randomData};
    
    // Message an invalid/corrupt object.
    // This will deadlock if called in a crash handler.
    [(as_bridge id)&corruptObj class];
}

+ (void) spinRunloop
{
    // From http://landonf.bikemonkey.org/2011/09/14
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        NSLog(@"ERROR: Run loop should be dead but isn't!");
    });
    *g_crasher_null_ptr = 1;
}

+ (void) causeStackOverflow
{
    [self causeStackOverflow];
}

+ (void) doAbort
{
    abort();
}

+ (void) doDiv0
{
    int value = 10;
    value /= g_crasher_denominator;
    NSLog(@"%d", value);
}

+ (void) doIllegalInstruction
{
    unsigned int data[] = {0x11111111, 0x11111111};
    void (*funcptr)() = (void (*)())data;
    funcptr();
}

@end
