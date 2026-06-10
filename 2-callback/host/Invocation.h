#pragma once

#include <cstdint>

namespace lore::utils {

    class Invocation {
    public:
        using InvocationArguments = void;
        using ReentryArguments = void;

        Invocation() = delete;
        ~Invocation() = delete;

        /// Start a native pass-through invocation.
        /// @param ia The invocation arguments.
        /// @param ra_ptr The pointer for caller to get the next reentry arguments.
        /// @return 0 if the invocation is complete, 1 if there is a reentry.
        static int64_t invoke(const InvocationArguments *ia, ReentryArguments **ra_ptr);

        /// Resume the invocation, called by the guest after a reentry.
        static int64_t resume();

        /// Reenter the invocation, called by the host during an invocation.
        /// @param ra The reentry arguments.
        static void reenter(ReentryArguments *ra);
    };

    extern int processInvocation(const Invocation::InvocationArguments *ia);

}
