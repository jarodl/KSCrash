//
//  KSMach.h
//
//  Created by Karl Stenerud on 12-01-29.
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


/* Utility functions for querying the mach kernel.
 */


#ifndef HDR_KSMach_h
#define HDR_KSMach_h

#ifdef __cplusplus
extern "C" {
#endif


#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <stdbool.h>
#include <sys/ucontext.h>


// ============================================================================
#pragma mark - General Information -
// ============================================================================

/** Get the total memory that is currently free.
 *
 * @return total free memory.
 */
uint64_t ksmach_freeMemory(void);

/** Get the total memory that is currently usable.
 *
 * @return total usable memory.
 */
uint64_t ksmach_usableMemory(void);

/** Get the current CPU architecture.
 *
 * @return The current architecture.
 */
const char* ksmach_currentCPUArch(void);

/** Get the name of a mach exception.
 *
 * @param exceptionType The exception type.
 *
 * @return The exception's name or NULL if not found.
 */
const char* ksmach_exceptionName(exception_type_t exceptionType);

/** Get the name of a mach kernel return code.
 *
 * @param code The return code.
 *
 * @return The code's name or NULL if not found.
 */
const char* ksmach_kernelReturnCodeName(kern_return_t returnCode);


// ============================================================================
#pragma mark - Thread State Info -
// ============================================================================

/** Fill in state information about a thread.
 *
 * @param thread The thread to get information about.
 *
 * @param state Pointer to buffer for state information.
 *
 * @param flavor The kind of information to get (arch specific).
 *
 * @param stateCount Number of entries in the state information buffer.
 *
 * @return true if state fetching was successful.
 */
bool ksmach_fillState(thread_t thread,
                      thread_state_t state,
                      thread_state_flavor_t flavor,
                      mach_msg_type_number_t stateCount);

/** Get the frame pointer for a machine context.
 * The frame pointer marks the top of the call stack.
 *
 * @param machineContext The machine context.
 *
 * @return The context's frame pointer.
 */
uintptr_t ksmach_framePointer(const _STRUCT_MCONTEXT* machineContext);

/** Get the address of the instruction about to be, or being executed by a
 * machine context.
 *
 * @param machineContext The machine context.
 *
 * @return The context's next instruction address.
 */
uintptr_t ksmach_instructionAddress(const _STRUCT_MCONTEXT* machineContext);

/** Get the address whose access caused the last fault.
 *
 * @param machineContext The machine context.
 *
 * @return The faulting address.
 */
uintptr_t ksmach_faultAddress(const _STRUCT_MCONTEXT* machineContext);

/** Get a thread's thread state and place it in a machine context.
 *
 * @param thread The thread to fetch state for.
 *
 * @param machineContext The machine context to store the state in.
 *
 * @return true if successful.
 */
bool ksmach_threadState(thread_t thread, _STRUCT_MCONTEXT* machineContext);

/** Get a thread's floating point state and place it in a machine context.
 *
 * @param thread The thread to fetch state for.
 *
 * @param machineContext The machine context to store the state in.
 *
 * @return true if successful.
 */
bool ksmach_floatState(thread_t thread, _STRUCT_MCONTEXT* machineContext);

/** Get a thread's exception state and place it in a machine context.
 *
 * @param thread The thread to fetch state for.
 *
 * @param machineContext The machine context to store the state in.
 *
 * @return true if successful.
 */
bool ksmach_exceptionState(thread_t thread, _STRUCT_MCONTEXT* machineContext);

/** Get the number of normal (not floating point or exception) registers the
 *  currently running CPU has.
 *
 * @return The number of registers.
 */
int ksmach_numRegisters(void);

/** Get the name of a normal register.
 *
 * @param regNumber The register index.
 *
 * @return The register's name or NULL if not found.
 */
const char* ksmach_registerName(int regNumber);

/** Get the value stored in a normal register.
 *
 * @param regNumber The register index.
 *
 * @return The register's current value.
 */
uint64_t ksmach_registerValue(const _STRUCT_MCONTEXT* machineContext,
                              int regNumber);

/** Get the number of exception registers the currently running CPU has.
 *
 * @return The number of registers.
 */
int ksmach_numExceptionRegisters(void);

/** Get the name of an exception register.
 *
 * @param regNumber The register index.
 *
 * @return The register's name or NULL if not found.
 */
const char* ksmach_exceptionRegisterName(int regNumber);

/** Get the value stored in an exception register.
 *
 * @param regNumber The register index.
 *
 * @return The register's current value.
 */
uint64_t ksmach_exceptionRegisterValue(const _STRUCT_MCONTEXT* machineContext,
                                       int regNumber);

/** Get the name of a thread's dispatch queue. Internally, a queue name will
 * never be more than 64 characters long.
 *
 * @param thread The thread whose name to get.
 *
 * @oaram buffer Buffer to hold the name.
 *
 * @param bufLength The length of the buffer.
 *
 * @return true if a name or label was found.
 */
bool ksmach_getThreadQueueName(thread_t thread, char* buffer, size_t bufLength);


// ============================================================================
#pragma mark - Binary Image Info -
// ============================================================================

/** Find a loaded binary image with the specified name.
 *
 * @param imageName The image name to look for.
 *
 * @param exactMatch If true, look for an exact match instead of a partial one.
 *
 * @return the index of the matched image, or UINT32_MAX if not found.
 */
uint32_t ksmach_imageNamed(const char* const imageName, bool exactMatch);

/** Get the UUID of a loaded binary image with the specified name.
 *
 * @param imageName The image name to look for.
 *
 * @param exactMatch If true, look for an exact match instead of a partial one.
 *
 * @return A pointer to the binary (16 byte) UUID of the image, or NULL if it
 *         wasn't found.
 */
const uint8_t* ksmach_imageUUID(const char* const imageName, bool exactMatch);

/** Get the address of the first command following a header (which will be of
 * type struct load_command).
 *
 * @param header The header to get commands for.
 *
 * @return The address of the first command, or NULL if none was found (which
 *         should not happen unless the header or image is corrupt).
 */
uintptr_t ksmach_firstCmdAfterHeader(const struct mach_header* header);


// ============================================================================
#pragma mark - Utility -
// ============================================================================

/** Suspend all threads except for the current one.
 *
 * @return true if thread suspention was at least partially successful.
 */
bool ksmach_suspendAllThreads(void);

/** Resume all threads except for the current one.
 *
 * @return true if thread resumption was at least partially successful.
 */
bool ksmach_resumeAllThreads(void);

/** Copy memory safely. If the memory is not accessible, returns false
 * rather than crashing.
 *
 * @param src The source location to copy from.
 *
 * @param dst The location to copy to.
 *
 * @param numBytes The number of bytes to copy.
 *
 * @return KERN_SUCCESS or an error code.
 */
kern_return_t ksmach_copyMem(const void* src, void* dst, size_t numBytes);

/** Get the difference in seconds between two timestamps fetched via
 * mach_absolute_time().
 *
 * @param endTime The greater of the two times.
 *
 * @param startTime The lesser of the two times.
 *
 * @return The difference between the two timestamps in seconds.
 */
double ksmach_timeDifferenceInSeconds(uint64_t endTime, uint64_t startTime);

/** Check if the current process is being traced or not.
 *
 * @return true if we're being traced.
 */
bool ksmach_isBeingTraced(void);

#ifdef __cplusplus
}
#endif

#endif // HDR_KSMach_h
