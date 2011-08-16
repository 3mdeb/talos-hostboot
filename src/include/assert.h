/** @file assert.h
 *  @brief Define the interfaces for the standard 'assert' macros.
 *
 *  There are four different assert types provided now:
 *      Standard assert behavior:
 *              assert(foo)
 *
 *      Standard assert behavior with a custom trace message:
 *              assert(foo, "This is a trace %d", 1234)
 *
 *      Critical assert, which should only be used by system libraries or
 *      code paths which cannot use trace or error logging:
 *              crit_assert(foo)
 *
 *      Kernel assert:
 *              kassert(foo)
 *
 *  Most code should use the standard asserts.  Kernel code must use kassert
 *  exclusively.  Usage of the critical assert should be limited to system
 *  library code (/src/lib, /src/sys) or init service, trace and error log.
 */
#ifndef _ASSERT_H
#define _ASSERT_H

#include <builtins.h>

#ifdef __HOSTBOOT_MODULE // Only allow traced assert in module code.
#include <trace/interface.H>
namespace TRACE { extern trace_desc_t* g_assertTraceBuffer; };
#endif

#ifdef __cplusplus
extern "C"
{
#endif

/** @enum AssertBehavior
 *  @brief Types of assert behavior used by the internal __assert function.
 */
enum AssertBehavior
{
        /** Standard assert, custom trace already done. */
    ASSERT_TRACE_DONE, 
        /** Standard assert, no custom trace. */
    ASSERT_TRACE_NOTDONE,
        /** Critical / System library assert. */
    ASSERT_CRITICAL,
        /** Kernel-level assert. */
    ASSERT_KERNEL,
};

/** @fn __assert
 *  @brief Internal function utilized by assert macros to commonize handling.
 *
 *  @param[in] i_assertb - Internal enumeration used by macros to communicate
 *                         desired behavior.
 *  @param[in] i_line - Line number at which the assert macro was called.
 *
 *  Current Behaviors:
 *      User-space application - A trace is created, either a custom one
 *                               provided by the caller or a common one 
 *                               determined by the trace callback hook, and 
 *                               the asserting task is ended.
 *
 *      Critical library - A printk is performed, similar in structure to the
 *                         traces, and the user task is ended.
 *
 *      Kernel - A printk is performed and a while(1) loop is entered to cease
 *               user-space dispatching.
 */
NO_RETURN
void __assert(AssertBehavior i_assertb, int i_line);

#ifdef __HOSTBOOT_MODULE // Only allow traced assert in module code.

// Macro tricks to determine if there is a custom string.
#define __ASSERT_HAS_TRACE_(_1, _2, ...) _2
#define __ASSERT_HAS_TRACE(...) __ASSERT_HAS_TRACE_(0, ##__VA_ARGS__, 0)

/** 
 * @brief Macro to do the custom trace if one is provided. 
 *
 * This results in larger code size of the caller to call the trace routines 
 * but may provide additional debug information.
 *
 * The "code" here will be compiled down to nothing or a single trace call by
 * the optimizer.  Search for "Constant Folding" for compiler background.
 */
#define __ASSERT_DO_TRACE(expr, ...) { \
            int __assert_unused_var = 0; \
            __assert_unused_var += (__ASSERT_HAS_TRACE(__VA_ARGS__) ? \
                TRACFCOMP(TRACE::g_assertTraceBuffer, \
                          "Assertion [ " #expr " ] failed; " __VA_ARGS__),1 \
                          : 0); \
            }

/** 
 * @brief Standard assert macro.
 *
 * Verfies condition, calls custom trace if provided, and calls internal
 * __assert function for remainder of common assert behavior.
 */
#define assert(expr,...) \
{\
    if (unlikely(!(expr)))\
    {\
        __ASSERT_DO_TRACE(expr, __VA_ARGS__); \
        __assert((__ASSERT_HAS_TRACE(__VA_ARGS__) ? \
                 ASSERT_TRACE_DONE : ASSERT_TRACE_NOTDONE),\
                 __LINE__);\
    }\
}

#else   // Only allow kernel assert in non-module code.

/**
 * @brief Kernel assert macro.
 *
 * Verifies condition and calls __assert function for common behavior.
 */
#define kassert(expr) \
{\
    if (unlikely(!(expr)))\
    {\
        __assert(ASSERT_KERNEL, __LINE__);\
    }\
}

#endif  // ifdef __HOSTBOOT_MODULE

// Allow critical assert anywhere.
/**
 * @brief Critical assert macro.
 *
 * Verifies condition and calls __assert function for common behavior.
 */
#define crit_assert(expr) \
{\
    if (unlikely(!(expr)))\
    {\
        __assert(ASSERT_CRITICAL, __LINE__);\
    }\
}



#ifdef NDEBUG  // Empty macro definitions for when NDEBUG is defined.
#ifdef MODULE
#undef assert
#define assert(expr,...) { }
#else
#undef kassert
#define kassert(expr) { }
#endif
#undef crit_assert
#define crit_assert(expr,...) { }
#endif



/** @brief  Make an assertion at compile time. If Boolean expression exp
 *  is false, then the compile will stop with an error.  Example usage:
 *            CPPASSERT( 2 == sizeof(compId_t));
 *  which would be used in front of errl flattening code that assumes  
 *  compId_t is 2 bytes in size.  Also with the use of -f short-enums 
 *  compiler switch, one could assert 
 *            CPPASSERT( 1 == sizeof(errlEventType_t));
 *  If the assertion fails, it will be a wakeup call that the errlEventType_t 
 *  enum has grown larger than a byte in size.  The mechanism to abend the
 *  compile when the expression is false is to cause a typedef of a char array
 *  that is -1 bytes in size.
 *
 *  Similar:  #define CHECK_SIZE(DATA, EXPECTED_SIZE)\
 *       typedef char CHECKSIZEVAR[(EXPECTED_SIZE == sizeof(DATA)) -1]
 * 
 */
#define CPPASSERT(exp) typedef char compile_time_assert_failed[2*((exp)!=0)-1]


#ifdef __cplusplus
};
#endif

#endif
