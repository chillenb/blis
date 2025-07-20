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

cmake_minimum_required(VERSION 3.22.0)
project(BLIS LANGUAGES C CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(HardwareDetection)

# Set the C standard to C99.
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED TRUE)
set(CMAKE_C_EXTENSIONS OFF)


# Enable IDE folders for targets.
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Find a python interpreter.
find_package(Python3 COMPONENTS Interpreter REQUIRED)
if(NOT Python3_FOUND)
    message(SEND_ERROR "Could not find working python interperter! Cannot continue.")
endif()



# automatic hardware detection
if(BLIS_CONFIG_FAMILY STREQUAL "auto")
    AutoHardwareDetection()
    set(BLIS_CONFIG_FAMILY ${HARDWARE_ARCH})
    message(STATUS "automatic configuration registered: " ${BLIS_CONFIG_FAMILY})
endif()





#------------------------------------
#           Option Setting
#------------------------------------



option(BUILD_SHARED_LIBS "Build shared libraries (.dll/.lib)" ON)
option(BUILD_STATIC_LIBS "Build static libraries (.lib/.a)" ON)
option(ENABLE_RPATH "Enable (disabled by default) setting an install_name for dynamic libraries on macOS which starts with @rpath rather than the absolute install path." OFF)


set(EXPORT_SHARED "public" CACHE STRING "Specify the subset of library symbols that are exported within a shared library.")
set_property(CACHE EXPORT_SHARED PROPERTY STRINGS "public" "all")


set(ENABLE_THREADING "auto" CACHE STRING "Enable threading in the library, using threading model(s) MODEL={single,openmp,pthreads,hpx,auto}")

option(ENABLE_TLS "Enable thread-local storage (TLS) for static variables in BLIS" ON)
option(ENABLE_SYSTEM "Enable conventional operating system support, such as pthreads for thread-safety." ON)
option(ENABLE_PBA_POOLS "Internal memory pools for packing block allocator" ON)
option(ENABLE_SBA_POOLS "Internal memory pools for small block allocator" ON)
option(ENABLE_MEM_TRACING "Memory tracing output" OFF)
# skip: asan

set(INT_SIZE "auto" CACHE STRING "BLIS API integer size")
set_property(CACHE INT_SIZE PROPERTY STRINGS "auto" "32" "64")
if(INT_SIZE STREQUAL "auto")
    set(INT_SIZE "0")
endif()

set(BLAS_INT_SIZE "auto" CACHE STRING "BLAS/CBLAS API integer size")
set_property(CACHE BLAS_INT_SIZE PROPERTY STRINGS "auto" "32" "64")
if(BLAS_INT_SIZE STREQUAL "auto")
    set(BLAS_INT_SIZE "0")
endif()


option(ENABLE_BLAS "BLAS compatiblity layer (enabled by default)" ON)
option(ENABLE_CBLAS "CBLAS compatiblity layer (disabled by default)" OFF)
option(ENABLE_SUP_HANDLING "Small matrix handling" ON)
option(ENABLE_AMD_FRAME_TWEAKS "AMD frame tweaks" OFF)
option(ENABLE_SCALAPACK_COMPAT "ScaLAPACK compatibility layer" OFF)

# skip: enable-addon
# skip: enable-sandbox

option(ENABLE_MEMKIND "libmemkind for manage memory pools" ON)

if(WIN32)
    set(ENABLE_MEMKIND OFF CACHE BOOL "libmemkind for manage memory pools")
endif()

option(ENABLE_TRSM_PREINVERSION "Enable TRSM preinversion" ON)


set(THREAD_PART_JRIR "slab" CACHE STRING "The method of assigning micropanels to threads in the JR and JR loops.")
set_property(CACHE THREAD_PART_JRIR PROPERTY STRINGS "slab" "rr")
if(THREAD_PART_JRIR STREQUAL "slab")
    message("   Requesting slab threading in jr and ir loops.")
    set(ENABLE_JRIR_SLAB ON)
    set(ENABLE_JRIR_RR OFF)
else()
    message("   Requesting round-robin threading in jr and ir loops.")
    set(ENABLE_JRIR_SLAB OFF)
    set(ENABLE_JRIR_RR ON)
endif()

# skip: force-version
# skip: show-config-lists

set(COMPLEX_RETURN "default" CACHE STRING "Specify the way in which complex numbers are returned from Fortran functions")
set_property(CACHE COMPLEX_RETURN PROPERTY STRINGS "default" "gnu" "intel")
if(CMAKE_Fortran_COMPILER_ID MATCHES "Intel*" AND COMPLEX_RETURN STREQUAL "default")
    set(COMPLEX_RETURN "intel")
endif()
if(COMPLEX_RETURN STREQUAL "intel")
    set(COMPLEX_RETURN_INTEL ON)
else()
    set(COMPLEX_RETURN_INTEL OFF)
endif()


set(BLIS_OPTION_LIST_01
    "ENABLE_SYSTEM"
    "ENABLE_TLS"
    "ENABLE_OPENMP"
    "ENABLE_PTHREADS"
    "ENABLE_HPX"
    "ENABLE_JRIR_SLAB"
    "ENABLE_JRIR_RR"
    "ENABLE_JRIR_TLB"
    "ENABLE_PBA_POOLS"
    "ENABLE_SBA_POOLS"
    "ENABLE_MEM_TRACING"
    "ENABLE_SCALAPACK_COMPAT"
    "ENABLE_BLAS"
    "ENABLE_CBLAS"
    "ENABLE_SUP_HANDLING"
    "ENABLE_MEMKIND"
    "ENABLE_TRSM_PREINVERSION"
    "ENABLE_PRAGMA_OMP_SIMD"
    "ENABLE_SANDBOX"
    "ENABLE_SHARED"
    "COMPLEX_RETURN_INTEL"
)

foreach(binary_option ${BLIS_OPTION_LIST_01})
    if(${binary_option})
        set("${binary_option}_01" 1)
    else()
        set("${binary_option}_01" 0)
    endif()
endforeach()




#------------------------------------
#           Check memkind
#------------------------------------
# Using libmemkind is not a valid option on Windows. Check only on Linux platforms.
if(NOT WIN32)
    # In order to determine the default behavior of the --with[out]-memkind
    # option, we try to detect whether libmemkind is available. If it is,
    # the default implied option will be --with-memkind; otherwise, will be
    # --without-memkind.
    try_compile(HAS_MEMKIND "${CMAKE_BINARY_DIR}/temp" SOURCES "${CMAKE_SOURCE_DIR}/build/detect/memkind/libmemkind_detect.c"
                LINK_OPTIONS
                    "-lmemkind"
                )
endif()

#------------------------------------
#       Check #pragma omp simd
#------------------------------------
# Try to determine whether the chosen compiler supports #pragma omp simd.
try_compile(PRAGMA_OMP_SIMD "${CMAKE_BINARY_DIR}/temp" SOURCES "${CMAKE_SOURCE_DIR}/build/detect/omp_simd/omp_simd_detect.c"
            CMAKE_FLAGS
                "-O3 -march=native -fopenmp-simd"
            C_STANDARD 99
            )
#------------------------------------
#       Acquire the BLIS version
#------------------------------------
# Set the VERSION variable to the default value in the 'version' file.
file(STRINGS ${CMAKE_SOURCE_DIR}/build/version VERSION)
file(STRINGS ${CMAKE_SOURCE_DIR}/build/so_version SO_VERSION)
# The first line of the 'so_version' file contains the .so major version.
list(GET SO_VERSION 0 SO_VERSION_MAJOR)
# The second line contains the minor and build .so version numbers
# (separated by a '.').
list(GET SO_VERSION 1 SO_VERSION_MINOR)

string(REPLACE "." ";" VERSION_LIST ${VERSION})
list(GET VERSION_LIST 0 VERSION_MAJOR)
list(GET VERSION_LIST 1 VERSION_MINOR)


#------------------------------------
#           Printing Options
#------------------------------------


# Initialize threading model, using the corresponding cache variable.
set(THREADING_MODEL ${ENABLE_THREADING})


#--------------------------------------------
# Instantiate bli_config.h file from template
#--------------------------------------------
# Begin substituting information into the build/cmake/bli_config.h.in file, outputting
# to bli_config.h and store it in build directory of the current project.
configure_file(build/bli_config.h.cmake.in ${PROJECT_BINARY_DIR}/bli_config.h)

#--------------------------------------------
# Instantiate bli_addon.h file from template
#--------------------------------------------
# Create a list of #includes, one for each addon in addon_list.
set(ADDON_LIST_INCLUDES "")
foreach(ADDON ${ENABLE_ADDON})
    set(ADDON_HEADER "\"${ADDON}.h\"")
    set(ADDON_LIST_INCLUDES "${ADDON_LIST_INCLUDES}#include ${ADDON_HEADER}\n")
endforeach()
# Begin substituting information into the bli_addon.h.in file, outputting
# to bli_addon.h and store it in build directory of the current project.
configure_file(build/bli_addon.h.cmake.in ${PROJECT_BINARY_DIR}/bli_addon.h)

#--------------------------------------------
#     Collect directory paths for blis.h
#--------------------------------------------
# Variable ALL_HEADER_PATHS_LIST is equivalent to ALL_H99_DIRPATHS in Make system.
# Practically, we collect the required directory paths into a list, which we
# append as we add the corresponding subdirectories. This variable will be
# transformed into a string and will be used to generate the flatten blis.h header.
set(ALL_HEADER_PATHS_LIST "")
# Track files to set dependencies for blis.h.
set(ALL_HEADER_FILES_LIST "")

# Include functionality that returns header paths.
include(SubdirHelperFunctions)

# If the CONFIG_LIST does not already contain the CONFIG_NAME (i.e.,
# if CONFIG_NAME is an umbrella family), add in the corresponding
# directory. (In the next step, we will loop over the actual sub-
# configurations and add them as well.)
list(FIND CONFIG_LIST ${BLIS_CONFIG_FAMILY} IS_UMBRELLA)
if(${IS_UMBRELLA} STREQUAL "-1")
    # Collect all subdirectory paths that have at least one file with suffix in ALL_H99_SUFS list.
    get_dirpaths_with_suffixes(${BLIS_CONFIG_FAMILY}_HEADER_PATHS ${CMAKE_SOURCE_DIR}/config/${BLIS_CONFIG_FAMILY} "${ALL_H99_SUFS}")
    # Collect all files in the subdirectories.
    get_filepaths_with_suffixes(${BLIS_CONFIG_FAMILY}_HEADER_FILES ${CMAKE_SOURCE_DIR}/config/${BLIS_CONFIG_FAMILY} "${ALL_H99_SUFS}")
endif()
list(APPEND ALL_HEADER_PATHS_LIST "${${BLIS_CONFIG_FAMILY}_HEADER_PATHS}")
list(APPEND ALL_HEADER_FILES_LIST "${${BLIS_CONFIG_FAMILY}_HEADER_FILES}")

# Get header directory paths for each of the sub-configurations present
# in the configuration list.
foreach(CONF ${CONFIG_LIST})
    get_dirpaths_with_suffixes(config_${CONF}_HEADER_PATHS ${CMAKE_SOURCE_DIR}/config/${CONF} "${ALL_H99_SUFS}")
    list(APPEND ALL_HEADER_PATHS_LIST "${config_${CONF}_HEADER_PATHS}")
    get_filepaths_with_suffixes(config_${CONF}_FILES_PATHS ${CMAKE_SOURCE_DIR}/config/${CONF} "${ALL_H99_SUFS}")
    list(APPEND ALL_HEADER_FILES_LIST "${config_${CONF}_HEADER_FILES}")
endforeach()

# Get header directory paths for each of the kernels present
# in the kernel list.
foreach(KERN ${KERNEL_LIST})
    # Collect all subdirectory paths that have at least one file with suffix in ALL_H99_SUFS list.
    get_dirpaths_with_suffixes(kernels_${KERN}_HEADER_PATHS ${CMAKE_SOURCE_DIR}/kernels/${KERN} "${ALL_H99_SUFS}")
    list(APPEND ALL_HEADER_PATHS_LIST "${kernels_${KERN}_HEADER_PATHS}")
    get_filepaths_with_suffixes(kernels_${KERN}_HEADER_FILES ${CMAKE_SOURCE_DIR}/kernels/${KERN} "${ALL_H99_SUFS}")
    list(APPEND ALL_HEADER_PATHS_FILES "${kernels_${KERN}_HEADER_FILES}")
endforeach()

# Get header directory paths for framework directory.
get_dirpaths_with_suffixes(frame_HEADER_PATHS ${CMAKE_SOURCE_DIR}/frame "${ALL_H99_SUFS}")
list(APPEND ALL_HEADER_PATHS_LIST "${frame_HEADER_PATHS}")
get_filepaths_with_suffixes(frame_HEADER_FILES ${CMAKE_SOURCE_DIR}/frame "${ALL_H99_SUFS}")
list(APPEND ALL_HEADER_FILES_LIST "${frame_HEADER_FILES}")


# Get a copy of the header paths without including the addons and the sandbox.
set(FRAME_HEADER_DIRPATHS_LIST ${ALL_HEADER_PATHS_LIST})

# Get header directory paths for each of the addons.
foreach(ADDON ${ENABLE_ADDON})
    get_dirpaths_with_suffixes(addon_${ADDON}_HEADER_PATHS ${CMAKE_SOURCE_DIR}/addon/${ADDON} "${ALL_H99_SUFS}")
    list(APPEND ALL_HEADER_PATHS_LIST "${addon_${ADDON}_HEADER_PATHS}")
    get_filepaths_with_suffixes(addon_${ADDON}_HEADER_FILES ${CMAKE_SOURCE_DIR}/addon/${ADDON} "${ALL_H99_SUFS}")
    list(APPEND ALL_HEADER_FILES_LIST "${addon_${ADDON}_HEADER_FILES}")
endforeach()

# Pick up generated bli_config.h and bli_addon.h that get generated in
# current build directory.
list(PREPEND ALL_HEADER_PATHS_LIST ${PROJECT_BINARY_DIR}/)
list(PREPEND ALL_HEADER_FILES_LIST ${PROJECT_BINARY_DIR}/bli_config.h)
if(NOT (ENABLE_ADDON STREQUAL ""))
    list(PREPEND ALL_HEADER_FILES_LIST ${PROJECT_BINARY_DIR}/bli_addon.h)
endif()

# Create a string out of this list so that it can be processed by flatten-headers.py.
list(JOIN ALL_HEADER_PATHS_LIST " " ALL_HEADER_PATHS_STRING)

#--------------------------------------------
#     Consolidated blis.h header creation
#--------------------------------------------
# Creating a directory for the generated flatten headers.
file(MAKE_DIRECTORY ${PROJECT_BINARY_DIR}/include/${BLIS_CONFIG_FAMILY})
# Flatten header python script file which expand header contents in blis.h.
add_custom_command(OUTPUT ${PROJECT_BINARY_DIR}/include/${BLIS_CONFIG_FAMILY}/blis.h
                COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/build/flatten-headers.py -c -v1
                "${CMAKE_SOURCE_DIR}/frame/include/blis.h"
                "${PROJECT_BINARY_DIR}/include/${BLIS_CONFIG_FAMILY}/blis.h"
                "${PROJECT_BINARY_DIR}/include"
                "${ALL_HEADER_PATHS_STRING}"
                COMMENT "Generating monolithic blis header file: ${PROJECT_BINARY_DIR}/include/${BLIS_CONFIG_FAMILY}/blis.h"
                DEPENDS ${ALL_HEADER_FILES_LIST}
                VERBATIM
                )
add_custom_target(flat-header DEPENDS ${PROJECT_BINARY_DIR}/include/${BLIS_CONFIG_FAMILY}/blis.h)
#--------------------------------------------
#     Consolidated cblas.h header creation
#--------------------------------------------
# Flatten header python script file which expand header contents in cblas.h.
if(ENABLE_CBLAS)
    add_custom_command(OUTPUT ${PROJECT_BINARY_DIR}/include/${BLIS_CONFIG_FAMILY}/cblas.h
                    COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/build/flatten-headers.py -c -v1
                    "${CMAKE_SOURCE_DIR}/frame/compat/cblas/src/cblas.h"
                    "${PROJECT_BINARY_DIR}/include/${BLIS_CONFIG_FAMILY}/cblas.h"
                    "${PROJECT_BINARY_DIR}/${include}"
                    "${ALL_HEADER_PATHS_STRING}"
                    COMMENT "Generating monolithic cblas header file: ${PROJECT_BINARY_DIR}/include/${BLIS_CONFIG_FAMILY}/cblas.h"
                    DEPENDS ${ALL_HEADER_FILES_LIST}
                    VERBATIM
                    )
    add_custom_target(flat-cblas-header DEPENDS ${PROJECT_BINARY_DIR}/include/${BLIS_CONFIG_FAMILY}/cblas.h)
endif()

#--------------------------------------------
#         Default linker definitions
#--------------------------------------------
# NOTE: This section needs to reside before the inclusion of make_defs.mk
# files (just below), as most configurations' make_defs.mk don't tinker
# with things like LDFLAGS, but some do (or may), in which case they can
# manually override whatever they need.

# Define the external libraries we may potentially need at link-time.
# Add libm only on Linux and only if Intel compiler is not used.
if((NOT WIN32) AND (NOT ("${CMAKE_C_COMPILER_ID}" MATCHES "Intel")))
    set(LIBM -lm)
endif()
set(LIBMEMKIND -lmemkind)

# Default linker flags.
# NOTE: -lpthread is needed unconditionally because BLIS uses pthread_once()
# to initialize itself in a thread-safe manner. The one exception to this
# rule: if --disable-system is given at configure-time, LIBPTHREAD is empty.
if(NOT WIN32)
    set(LDFLAGS ${LIBM} ${LIBPTHREAD})
endif()
# Add libmemkind to the link-time flags, if it was enabled at configure-time.
if(ENABLE_MEMKIND STREQUAL "yes")
    list(APPEND LDFLAGS ${LIBMEMKIND})
endif()

#--------------------------------------------
#         Code-coverage flags
#--------------------------------------------
if(ENABLE_COVERAGE AND (NOT WIN32))
    set(COVERAGE_FLAGS "-fprofile-arcs -ftest-coverage")
    list(APPEND CMAKE_C_FLAGS ${COVERAGE_FLAGS})
endif()

#--------------------------------------------
#         Address Sanitizer flags
#--------------------------------------------
if(ENABLE_ASAN AND (NOT WIN32))
    set(ASAN_FLAGS "-g -fsanitize=address")
    list(APPEND CMAKE_C_FLAGS ${ASAN_FLAGS})
endif()

#--------------------------------------------
#         Configuration-agnostic flags
#--------------------------------------------
# --- Warning flags ---

# Disable unused function warnings and stop compiling on first error for
# all compilers that accept such options: gcc, clang, and icc.
set(CWARNFLAGS -Wno-unused-function -Wfatal-errors)
if(NOT WIN32)
    list(PREPEND CWARNFLAGS -Wall)
endif()

# Disable tautological comparision warnings in clang.
if("${CMAKE_C_COMPILER_ID}" MATCHES "Clang")
    list(APPEND CWARNFLAGS -Wno-tautological-compare -Wno-pass-failed)
endif()

# Add extra warning flags for Windows builds.
if(WIN32)
    list(APPEND CWARNFLAGS -Wno-unused-variable -Wno-deprecated-declarations)
endif()

#Setting up the correct Windows Runtime Library.
if(WIN32)
    cmake_policy(SET CMP0091 NEW)
    if(BUILD_SHARED_LIBS)
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
    else()
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    endif()
endif()

# --- Symbol exporting flags (shared libraries only) --

# NOTE: These flags are only applied when building BLIS and not used by
# applications.

# Determine default export behavior / visibility of symbols for gcc, icc and clang.
if(NOT WIN32)
    if(EXPORT_SHARED STREQUAL "all")
        # Export all symbols by default.
        set(BUILD_SYMFLAGS -fvisibility=default)
    else() # ifeq ($(EXPORT_SHARED),public)
        # Hide all symbols by default and export only those that have been annotated
        # as needing to be exported.
        set(BUILD_SYMFLAGS -fvisibility=hidden)
    endif()
endif()

# Macro to remove/replace absolute path within library
list(APPEND BUILD_SYMFLAGS "-fmacro-prefix-map=${CMAKE_SOURCE_DIR}/=")

# --- C Preprocessor flags ---
# Enable clock_gettime() in time.h.
set(CPPROCFLAGS -D_POSIX_C_SOURCE=200112L)

# --- Threading flags ---
# NOTE: We don't have to explicitly omit -pthread when --disable-system is given
# since that option forces --enable-threading=none, and thus -pthread never gets
# added to begin with.
if(NOT WIN32)
    if(THREADING_MODEL STREQUAL "pthreads")
        set(CTHREADFLAGS "-pthread")
    endif()
endif()

# --- #pragma omp simd flags (used for reference kernels only) ---
if(PRAGMA_OMP_SIMD)
    if(WIN32)
        set(COMPSIMDFLAGS /openmp:experimental)
    else()
        set(COMPSIMDFLAGS -fopenmp-simd)
    endif()
endif()

#--------------------------------------------
#     Compiler include path definitions
#--------------------------------------------
# Obtain a list of header files #included inside of the bli_cntx_ref.c file.
# Due to the way that bli_cntx_ref.c uses headers and macros, paths to these
# files will be needed when compiling bli_cntx_ref.c with the monolithic header.

# Read content of bli_cntx_ref.c and put it in REF_KER_HEADERS_TEMP.
file(STRINGS ${CMAKE_SOURCE_DIR}/ref_kernels/bli_cntx_ref.c REF_KER_HEADERS_TEMP)
# Only keep the lines where there are includes.
list(FILTER REF_KER_HEADERS_TEMP INCLUDE REGEX "\#include")
# REF_KER_HEADERS has a list of all files that are included in bli_cntx_ref.c.
set(REF_KER_HEADERS "")
foreach(header ${REF_KER_HEADERS_TEMP})
    string(REGEX MATCH "\#include [\"<]\([a-zA-Z0-9\_\.\/\-]*\)[\">].*" helper ${header})
    list(APPEND REF_KER_HEADERS ${CMAKE_MATCH_1})
endforeach()
# Remove blis.h from the list.
list(FILTER REF_KER_HEADERS EXCLUDE REGEX "blis.h")
set(REF_KER_H_PATHS "")
foreach(header_name ${REF_KER_HEADERS})
    foreach(header_dir ${FRAME_HEADER_DIRPATHS_LIST})
        if(EXISTS ${header_dir}/${header_name})
            list(APPEND REF_KER_H_PATHS ${header_dir})
            break()
        endif()
    endforeach()
endforeach()
# Remove duplicates, if they exist.
list(REMOVE_DUPLICATES REF_KER_H_PATHS)

# Create list of include directories, to be used while creating the library.
# NOTE: We no longer need every header path in the source tree since we
# now #include the monolithic/flattened blis.h instead.
set(CINFLAGS ${PROJECT_BINARY_DIR}/include/${BLIS_CONFIG_FAMILY})
list(APPEND CINFLAGS ${REF_KER_H_PATHS})
# Then add frame/include since it's needed for bli_oapi_w[o]_cntx.h.
list(APPEND CINFLAGS ${CMAKE_SOURCE_DIR}/frame/include)
# If CBLAS is enabled, we also include the path to the cblas.h directory so
# that the compiler will be able to find cblas.h as the CBLAS source code is
# being compiled.
if(ENABLE_CBLAS)
    set(CBLAS_H_DIRPATH "")
    foreach(header_dir ${FRAME_HEADER_DIRPATHS_LIST})
        if(EXISTS ${header_dir}/cblas.h)
            list(APPEND CBLAS_H_DIRPATH ${header_dir})
            break()
        endif()
    endforeach()
    list(APPEND CINFLAGS ${CBLAS_H_DIRPATH})
endif()

#--------------------------------------------
#   Special preprocessor macro definitions
#--------------------------------------------
# Define a C preprocessor macro to communicate the current version so that it
# can be embedded into the library and queried later.
set(VERS_DEF -DBLIS_VERSION_STRING="${VERSION_STRING}")

# Define a C preprocessor flag that is *only* defined when BLIS is being
# compiled. (In other words, an application that #includes blis.h will not
# get this cpp macro.)
set(BUILD_CPPFLAGS -DBLIS_IS_BUILDING_LIBRARY)

#--------------------------------------------
#     Add CMakeLists.txt from directories
#--------------------------------------------
# Add config subdirectory.
add_subdirectory(config)
# Add kernel subdirectory.
add_subdirectory(kernels)
# Add framework directory.
add_subdirectory(frame)
# Add AOCL DTL logs directory.
add_subdirectory(aocl_dtl)
# Add subdirectory for each of the addons.
list(LENGTH ENABLE_ADDON addon_list_size)
if(addon_list_size GREATER 0)
    add_subdirectory(addon)
endif()

# Collect all object libraries that are required to build the blis library.
set(OBJECT_LIBRARIES "")
# Add objects from config.
foreach(conf ${CONFIG_LIST})
    list(APPEND OBJECT_LIBRARIES $<TARGET_OBJECTS:${conf}_CONFIG>)
endforeach()
# Add objects from kernels.
foreach(ker ${KERNEL_LIST})
    if(TARGET ${ker}_KERNELS)
        list(APPEND OBJECT_LIBRARIES $<TARGET_OBJECTS:${ker}_KERNELS>)
    endif()
    if(TARGET ${ker}_LPGEMM_KERNELS)
        list(APPEND OBJECT_LIBRARIES $<TARGET_OBJECTS:${ker}_LPGEMM_KERNELS>)
    endif()
endforeach()
# Add objects for reference kernels.
foreach(conf ${CONFIG_LIST})
    list(APPEND OBJECT_LIBRARIES $<TARGET_OBJECTS:${conf}_REFINIT>)
    list(APPEND OBJECT_LIBRARIES $<TARGET_OBJECTS:${conf}_REFKERN>)
endforeach()
# Add objects for frame.
list(APPEND OBJECT_LIBRARIES $<TARGET_OBJECTS:FRAME>)
# Add objects for aocl-dtl.
list(APPEND OBJECT_LIBRARIES $<TARGET_OBJECTS:AOCL_DTL>)
# Add objects for addons.
foreach(addon ${ENABLE_ADDON})
    if(TARGET ${addon}_C99_ADDON)
        list(APPEND OBJECT_LIBRARIES $<TARGET_OBJECTS:${addon}_C99_ADDON>)
    endif()
    if(TARGET ${addon}_C99_KERNEL_ADDON)
        list(APPEND OBJECT_LIBRARIES $<TARGET_OBJECTS:${addon}_C99_KERNEL_ADDON>)
    endif()
    if(TARGET ${addon}_CXX_ADDON)
        list(APPEND OBJECT_LIBRARIES $<TARGET_OBJECTS:${addon}_CXX_ADDON>)
    endif()
endforeach()

#--------------------------------------------
#         Building BLIS Library
#--------------------------------------------
# Public blis headers.
set(BLIS_PUBLIC_HEADERS
    ${PROJECT_BINARY_DIR}/include/${BLIS_CONFIG_FAMILY}/blis.h
    # Include AMD's C++ template header files in the list of headers
    # to install.
    ${CMAKE_SOURCE_DIR}/vendor/cpp/blis.hh
    ${CMAKE_SOURCE_DIR}/vendor/cpp/cblas.hh
)
if(ENABLE_CBLAS)
    list(APPEND BLIS_PUBLIC_HEADERS ${PROJECT_BINARY_DIR}/include/${BLIS_CONFIG_FAMILY}/cblas.h)
endif()

# --- Library name and local paths ---
# From old CMake
if(WIN32)
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
    add_definitions(-D_CRT_SECURE_NO_DEPRECATE)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /Oi")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /MP${CMake_MSVC_PARALLEL}")
    set(INTR_GENERAL_LINK_FLAGS "${INTR_GENERAL_LINK_FLAGS} /RELEGE")
    add_definitions(-DEXPMODULE)
endif()

# Set up the library name.
if(WIN32)
    set(LIBBLIS AOCL-LibBlis-Win)
else()
    set(LIBBLIS blis)
endif()

# Append if threading is required.
if(NOT (THREADING_MODEL STREQUAL "no"))
    if(WIN32)
        string(APPEND LIBBLIS -MT)
    else()
        string(APPEND LIBBLIS -mt)
    endif()
endif()

set(LIBBLIS_STATIC ${LIBBLIS})
set(LIBBLIS_SHARED ${LIBBLIS})
if(WIN32)
    string(APPEND LIBBLIS_SHARED -dll)
endif()

if(THREADING_MODEL STREQUAL "no")
    set(PC_IN_FILE "blis.pc.in")
    set(PC_OUT_FILE "blis.pc")
else()
    set(PC_IN_FILE "blis-mt.pc.in")
    set(PC_OUT_FILE "blis-mt.pc")
endif()

# Set directories for installation of libraries and header files.
set(LIB_DIR ${CMAKE_INSTALL_PREFIX}/lib)
set(INCLUDE_DIR ${CMAKE_INSTALL_PREFIX}/include)
# Set LDFLAGS to be replaced in pc file.
set(LDFLAGS_STRING ${LDFLAGS})
# Add OpenMP flags as required.
if(THREADING_MODEL STREQUAL "openmp")
 list(APPEND LDFLAGS_STRING "${OpenMP_C_FLAGS}")
endif()
string(JOIN " " LDFLAGS_STRING ${LDFLAGS_STRING})
if(NOT WIN32)
    configure_file(
        ${CMAKE_SOURCE_DIR}/build/cmake/${PC_IN_FILE}
        ${CMAKE_BINARY_DIR}/${PC_OUT_FILE}
        @ONLY
    )
endif()
include(GNUInstallDirs)

if(BUILD_SHARED_LIBS)
    # Build shared library.
    add_library(libblis-shared SHARED ${OBJECT_LIBRARIES})
    target_link_libraries(libblis-shared PRIVATE ${LDFLAGS})
    set_target_properties(libblis-shared PROPERTIES LINKER_LANGUAGE C VERSION ${VERSION} SOVERSION ${SO_VERSION_MAJOR})
    set_target_properties(libblis-shared PROPERTIES POSITION_INDEPENDENT_CODE ON)
    if(THREADING_MODEL STREQUAL "openmp")
        if((NOT ${OpenMP_libomp_LIBRARY} STREQUAL "") AND (NOT WIN32))
            target_link_libraries(libblis-shared PRIVATE ${OpenMP_libomp_LIBRARY})
        else()
            target_link_libraries(libblis-shared PRIVATE OpenMP::OpenMP_C)
        endif()
    endif()
    add_dependencies(libblis-shared flat-header)
    if(ENABLE_CBLAS)
        add_dependencies(libblis-shared flat-cblas-header)
    endif()
    # Add headers as a property to the library.
    set_target_properties(libblis-shared PROPERTIES PUBLIC_HEADER "${BLIS_PUBLIC_HEADERS}")
    set_target_properties(libblis-shared PROPERTIES OUTPUT_NAME ${LIBBLIS_SHARED})
    # Install targets for shared.
    install(TARGETS libblis-shared LIBRARY DESTINATION ${CMAKE_INSTALL_PREFIX}/lib
            ARCHIVE DESTINATION ${CMAKE_INSTALL_PREFIX}/lib
            RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/lib
            PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_PREFIX}/include)
    set(libblis_depends libblis-shared)
endif()
if(BUILD_STATIC_LIBS OR NOT BUILD_SHARED_LIBS)
    # Build static library.
    add_library(libblis-static STATIC ${OBJECT_LIBRARIES})
    set_target_properties(libblis-static PROPERTIES LINKER_LANGUAGE C)
    # Setting this for static to fix issues where test programs built with gcc 9.4.0 fail to link versions of BLIS build with AOCC 4.0.0.
    set_target_properties(libblis-static PROPERTIES POSITION_INDEPENDENT_CODE ON)
    add_dependencies(libblis-static flat-header)
    if(ENABLE_CBLAS)
        add_dependencies(libblis-static flat-cblas-header)
    endif()
    # Add headers as a property to the library.
    set_target_properties(libblis-static PROPERTIES PUBLIC_HEADER "${BLIS_PUBLIC_HEADERS}")
    set_target_properties(libblis-static PROPERTIES OUTPUT_NAME ${LIBBLIS_STATIC})
    # Install targets.
    install(TARGETS libblis-static LIBRARY DESTINATION ${CMAKE_INSTALL_PREFIX}/lib
            ARCHIVE DESTINATION ${CMAKE_INSTALL_PREFIX}/lib
            RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/lib
            PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_PREFIX}/include)
    list(APPEND libblis_depends libblis-static)
endif()

if(NOT WIN32)
    # Install package-config file.
    install(FILES ${CMAKE_BINARY_DIR}/${PC_OUT_FILE} DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/pkgconfig)
endif()

# Set libblis to the shared or static libblis depending on the option setting.
if(TEST_WITH_SHARED)
    set(libblis_link libblis-shared)
else()
    set(libblis_link libblis-static)
endif()

# --- Primary targets ---
add_custom_target(libblis DEPENDS ${libblis_depends})
add_custom_target(libs DEPENDS ${libblis})

# Multiple BLIS API testing targets. Result files are generated in ${CMAKE_BINARY_DIR}/testsuite.
add_subdirectory(testsuite EXCLUDE_FROM_ALL)

# Check results of BLIS CPP Template tests
add_subdirectory(vendor/testcpp EXCLUDE_FROM_ALL)

# Add BLAS tests if BLAS interface is enabled.
if(ENABLE_BLAS)
    add_subdirectory(blastest EXCLUDE_FROM_ALL)
endif()

if(ENABLE_BLAS AND WIN32 AND BUILD_SHARED_LIBS)
set(DETAILED_BLATEST_MESSAGE "Details: Level2 and level3 API tests define a custom version of xerbla_() to test the error codes. \
On Linux and on Windows/static versions of BLIS library, the custom xerbla_() gets called inside the library\
due to the linking process and all tests work. On Windows/shared version of the library, symbol resolution\
happens at load-time so the blis implementation of xerbla_() gets called instead of the custom one. \
That causes errors when the tests are run which are independent of the BLIS library. \
Please use static builds only on Windows.")
endif()

# Add generic testing target `test`.
set(available_testsuites checkblis)
if(ENABLE_BLAS)
    list(APPEND available_testsuites checkblas)
endif()

if(WIN32 AND BUILD_SHARED_LIBS)
    if(ENABLE_BLAS)
        set(TEST_WARNING "Target `test` depends only on target `checkblis` because `checkblas` target is not available on Windows for shared builds of BLIS. ")
    endif()
else()
    if(ENABLE_BLAS)
        list(APPEND available_testsuites checkblas)
    endif()
endif()
add_custom_target(tests
                DEPENDS ${available_testsuites}
                COMMENT "Running target `test`. ${TEST_WARNING} ${DETAILED_BLATEST_MESSAGE}")

# Add generic testing target `check`.
set(available_testsuites checkblis-fast)
if(WIN32 AND BUILD_SHARED_LIBS)
    if(ENABLE_BLAS)
        set(CHECK_WARNING "Target `check` depends only on target `checkblis-fast` because `checkblas` target is not available on Windows for shared builds of BLIS. ")
    endif()
else()
    if(ENABLE_BLAS)
        list(APPEND available_testsuites checkblas)
    endif()
endif()
add_custom_target(check
                DEPENDS ${available_testsuites}
                COMMENT "Running target `check`. ${CHECK_WARNING} ${DETAILED_BLATEST_MESSAGE}")

add_subdirectory(bench EXCLUDE_FROM_ALL)

add_subdirectory(test EXCLUDE_FROM_ALL)