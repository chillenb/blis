#  BLIS
#  An object-based framework for developing high-performance BLAS-like
#  libraries.
#
#  Copyright (C) 2014, The University of Texas at Austin
#  Copyright (C) 2020-2022, Advanced Micro Devices, Inc.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are
#  met:
#   - Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   - Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#   - Neither the name(s) of the copyright holder(s) nor the names of its
#     contributors may be used to endorse or promote products derived
#     from this software without specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
#  HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# # Translated from check_compiler() in configure script


function(echoerr_unsupportedcc)
    message(FATAL_ERROR "*** Unsupported compiler version: ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION} at ${CMAKE_C_COMPILER}.")
endfunction()

function(blacklistcc_add config_name)
    if(NOT config_name IN_LIST config_blist)
        list(APPEND config_blist "${config_name}")
        message(WARNING "*** ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION} compiler does not support ${config_name}, adding to blacklist.")
        set(config_blist "${config_blist}" PARENT_SCOPE)
    endif()
endfunction()


function(GetBlacklistedConfigs)

	#
	# Compiler requirements
	#
	# General:
	#
	#   icc 15+, gcc 4.7+, clang 3.3+
	#
	# Specific:
	#
	#   skx: icc 15.0.1+, gcc 6.0+, clang 3.9+
	#   knl: icc 14.0.1+, gcc 5.0-14, clang 3.9+
	#   haswell: any
	#   sandybridge: any
	#   penryn: any
	#
	#   zen: gcc 6.0+[1], clang 4.0+
	#   zen2: gcc 6.0+[1], clang 4.0+
	#   zen3: gcc 6.0+[1], clang 4.0+
	#   excavator: gcc 4.9+, clang 3.5+
	#   steamroller: any
	#   piledriver: any
	#   bulldozer: any
	#
	#   cortexa57: any
	#   cortexa15: any
	#   cortexa9: any
	#
	#   armsve: clang11+, gcc10+
	#
	#   generic: any
	#
	# Note: These compiler requirements were originally modeled after similar
	# requirements encoded into TBLIS's configure.ac [2].
	#
	# [1] While gcc 6.0 or newer is needed for zen support (-march=znver1),
	#     we relax this compiler version constraint a bit by targeting bdver4
	#     and then disabling the instruction sets that were removed in the
	#     transition from bdver4 to znver1. (See config/zen/make_defs.mk for
	#     the specific compiler flags used.)
	# [2] https://github.com/devinamatthews/tblis/
	#

	message(STATUS "${script_name}: checking for blacklisted configurations due to ${cc} ${cc_version}.")

	# Fixme: check on a64fx, neoverse, and others

    string(REPLACE "." ";" cc_version_list "${CMAKE_C_COMPILER_VERSION}")
    # Get the major, minor, and revision version numbers.
    list(GET cc_version_list 0 cc_major)
    list(GET cc_version_list 1 cc_minor)
    list(GET cc_version_list 2 cc_revision)

	# gcc
	if(CMAKE_C_COMPILER_ID STREQUAL "GNU")

		if(cc_major LESS 4)
			echoerr_unsupportedcc()
		endif()
		if(cc_major EQUAL 4)
			blacklistcc_add("knl")
			if(cc_minor LESS 7)
				echoerr_unsupportedcc()
			endif()
			if(cc_minor LESS 9)
				blacklistcc_add("excavator")
				blacklistcc_add("zen")
			endif()
		endif()
		if(cc_major LESS 5 OR cc_major GREATER 14)
			blacklistcc_add("knl")
		endif()
		if(cc_major LESS 6)
			# Normally, zen would be blacklisted for gcc prior to 6.0.
			# However, we have a workaround in place in the zen
			# configuration's make_defs.mk file that starts with bdver4
			# and disables the instructions that were removed in znver1.
			# Thus, this "blacklistcc_add" statement has been moved above.
			#blacklistcc_add("zen")
			blacklistcc_add("skx")
			# gcc 5.x may support POWER9 but it is unverified.
			blacklistcc_add("power9")
		endif()
		if(cc_major LESS 10)
			blacklistcc_add("armsve")
		endif()
	endif()

	# icc
	if(CMAKE_C_COMPILER_ID STREQUAL "Intel")

		if(cc_major LESS 15)
			echoerr_unsupportedcc()
		endif()
		if(cc_major EQUAL 15)
			if(cc_revision LESS 1)
				blacklistcc_add("skx")
			endif()
		endif()
		if(cc_major EQUAL 18)
			message(WARNING "${script_name}: ${cc} ${cc_version} is known to cause erroneous results. See https://github.com/flame/blis/issues/371 for details.")
			blacklistcc_add("knl")
			blacklistcc_add("skx")
		endif()
		if(cc_major GREATER_EQUAL 19)
			message(WARNING "${script_name}: ${cc} ${cc_version} is known to cause erroneous results. See https://github.com/flame/blis/issues/371 for details.")
			echoerr_unsupportedcc()
		endif()
	endif()

	# Apple clang
	if(CMAKE_C_COMPILER_ID STREQUAL "AppleClang")
        if(cc_major LESS 5)
            echoerr_unsupportedcc()
        endif()
        # See https://en.wikipedia.org/wiki/Xcode#Toolchain_versions
        if(cc_major EQUAL 5)
            # Apple clang 5.0 is clang 3.4svn
            blacklistcc_add("excavator")
            blacklistcc_add("zen")
        endif()
        if(cc_major LESS 7)
            blacklistcc_add("knl")
            blacklistcc_add("skx")
        endif()
    endif()
	if(CMAKE_C_COMPILER_ID STREQUAL "Clang")
        if(cc_major LESS 3)
            echoerr_unsupportedcc()
        endif()
        if(cc_major EQUAL 3)
            if(cc_minor LESS 3)
                echoerr_unsupportedcc()
            endif()
            if(cc_minor LESS 5)
                blacklistcc_add("excavator")
                blacklistcc_add("zen")
            endif()
            if(cc_minor LESS 9)
                blacklistcc_add("knl")
                blacklistcc_add("skx")
            endif()
        endif()
        if(cc_major LESS 11)
            blacklistcc_add("armsve")
        endif()
	endif()
    set(config_blist "${config_blist}" PARENT_SCOPE)
endfunction()
