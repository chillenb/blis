#[=[

   BLIS
   An object-based framework for developing high-performance BLAS-like
   libraries.

   Copyright (C) 2022 - 2025, Advanced Micro Devices, Inc. All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are
   met:
    - Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    - Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    - Neither the name(s) of the copyright holder(s) nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
   HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

]=]

function(AutoHardwareDetection)
    message(STATUS "automatic configuration requested")
    set(auto_detect_source_files
        "${PROJECT_SOURCE_DIR}/build/detect/config/config_detect.c"
        "${PROJECT_SOURCE_DIR}/frame/base/bli_arch.c"
        "${PROJECT_SOURCE_DIR}/frame/base/bli_cpuid.c"
        "${PROJECT_SOURCE_DIR}/frame/base/bli_env.c"
       )
    set(frame_include " ${PROJECT_SOURCE_DIR}/frame/include")
    set(base_include " ${PROJECT_SOURCE_DIR}/frame/base")
    set(thread_include " ${PROJECT_SOURCE_DIR}/frame/thread")
    # Try building an executable from one or more source files.
    # Build success returns TRUE and build failure returns FALSE in COMPILERESULT.
    # If the build succeeds, this runs the executable and stores the exit code in RUNRESULT.
    # If the executable was built, but failed to run, then RUNRESULT will be set to FAILED_TO_RUN
    # RUN_OUTPUT_VARIABLE <var> Report the output from running the executable in a given variable

    execute_process(COMMAND grep "BLIS_CONFIG_" ${PROJECT_SOURCE_DIR}/frame/base/bli_cpuid.c
                    COMMAND sed -Ee "s/#ifdef[[:space:]]+/-D/g"
                    OUTPUT_VARIABLE config_defines)
    string(REPLACE  "\n" " " config_defines "${config_defines}")

    try_run(RUNRESULT COMPILERESULT "${PROJECT_BINARY_DIR}/temp" SOURCES ${auto_detect_source_files}
            COMPILE_DEFINITIONS -I${frame_include} -I${base_include} -I${thread_include}  -DBLIS_CONFIGURETIME_CPUID ${config_defines}
            RUN_OUTPUT_VARIABLE HARDWARE_ARCH
    )
    string(STRIP "${HARDWARE_ARCH}" HARDWARE_ARCH)
    message(STATUS "automatic hardware detection: " ${HARDWARE_ARCH})
    set(HARDWARE_ARCH "${HARDWARE_ARCH}" PARENT_SCOPE)
endfunction()
