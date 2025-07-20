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

# Translated from configure script

# Helper function to check if a list is a singleton
function(is_singleton input_list result_var)
    set(is_single FALSE)
    if(input_list)
        list(LENGTH input_list list_length)
        if(list_length EQUAL 1)
            set(is_single TRUE)
        endif()
    endif()
    set(${result_var} ${is_single} PARENT_SCOPE)
endfunction()

# Helper function to check if a family is a singleton family
function(is_singleton_family family_name member_list result_var)
    set(is_singleton_fam FALSE)
    
    is_singleton("${member_list}" is_single)
    
    if(is_single)
        list(GET member_list 0 first_member)
        if("${first_member}" STREQUAL "${family_name}")
            set(is_singleton_fam TRUE)
        endif()
    endif()
    
    set(${result_var} ${is_singleton_fam} PARENT_SCOPE)
endfunction()

# Helper function to assign key-value pair to a registry (stores as native CMake list)
function(assign_key_value registry_name key value)
    set(${registry_name}_${key} "${value}" PARENT_SCOPE)
endfunction()

# Helper function to query a value from a registry
function(query_registry registry_name key result_var)
    if(DEFINED ${registry_name}_${key})
        set(${result_var} "${${registry_name}_${key}}" PARENT_SCOPE)
    else()
        set(${result_var} "" PARENT_SCOPE)
    endif()
endfunction()


# Main function to pass configuration and kernel registries
function(pass_config_kernel_registries filename passnum)

    # Initialize a list of indirect blacklisted configurations for the
    # current iteration. These are configurations that are invalidated by
    # the removal of blacklisted configurations.
    if(passnum EQUAL 0)
        set(indirect_blist "" PARENT_SCOPE)
    endif()

    # For convenience, merge the original and indirect blacklists.
    # NOTE: During pass 0, all_blist is equal to config_blist, since
    # indirect_blist is still empty.
    set(all_blist "${config_blist}")
    if(indirect_blist)
        list(APPEND all_blist ${indirect_blist})
    endif()
    set(all_blist "${all_blist}" PARENT_SCOPE)
    
    # Disable support for indirect blacklisting by returning early during
    # pass 0. See issue #214 for details. Basically, indirect blacklisting 
    # is not needed in the use case that was originally envisioned.
    if(passnum EQUAL 0)
        return()
    endif()

    # Read the file line by line
    if(EXISTS "${filename}")
        file(STRINGS "${filename}" file_lines)
        
        foreach(line IN LISTS file_lines)
            set(curline "${line}")
            
            # Remove everything after comment character '#'
            string(REGEX REPLACE "#.*$" "" curline "${curline}")
            
            # Strip whitespace and skip empty lines
            string(STRIP "${curline}" curline)
            string(REGEX REPLACE "[ \t]+" " " curline "${curline}")
            if("${curline}" STREQUAL "")
                continue()
            endif()
            
            # Read the config name and config list for the current line using regex
            if(NOT curline MATCHES "^([^:]+):(.*)$")
                continue() # Skip malformed lines
            endif()
            
            set(cname "${CMAKE_MATCH_1}")
            set(list_string "${CMAKE_MATCH_2}")
            
            # Clean up the name and list
            string(STRIP "${cname}" cname)
            string(STRIP "${list_string}" list_string)
            string(REGEX REPLACE "[ \t]+" " " list_string "${list_string}")

            # If we encounter a slash, it means the name of the configuration
            # and the kernel set needed by that configuration are different.
            string(FIND "${list_string}" "/" slash_pos)
            if(slash_pos GREATER -1)
                # Slash found - parse configuration/kernel mappings
                set(klist)
                set(clist)
                string(REPLACE "/" ";" list_items "${list_string}")
                list(POP_FRONT list_items config)
                list(APPEND klist "${list_items}")
                list(APPEND clist "${config}")
            else()
                # Slash not found
                string(REPLACE " " ";" klist "${list_string}")
                string(REPLACE " " ";" clist "${list_string}")
            endif()

            
            # Add cname to full_config_list. Duplicates will be filtered out later.
            list(APPEND full_config_list "${cname}")
            set(full_config_list "${full_config_list}" PARENT_SCOPE)
            
            # Handle singleton and umbrella configuration entries separately
            is_singleton_family("${cname}" "${clist}" is_singleton_fam)

            if(is_singleton_fam)
                # Singleton configurations/families
                # Note: for singleton families, clist contains one item, which
                # always equals cname, but klist could contain more than one item.
                
                # Add the kernels in klist to full_kernel_list
                list(APPEND full_subconfig_list "${cname}")
                list(APPEND full_kernel_list "${klist}")
                set(full_subconfig_list "${full_subconfig_list}" PARENT_SCOPE)
                set(full_kernel_list "${full_kernel_list}" PARENT_SCOPE)
                
                # Only consider updating registries if the configuration name is not blacklisted
                if(NOT "${cname}" IN_LIST all_blist)
                    if(passnum EQUAL 0)
                        # Check klist for blacklisted items
                        foreach(item IN LISTS klist)
                            if("${item}" IN_LIST config_blist)
                                list(APPEND indirect_blist "${cname}")
                                set(indirect_blist "${indirect_blist}" PARENT_SCOPE)
                                break()
                            endif()
                        endforeach()
                    endif()
                    
                    if(passnum EQUAL 1)
                        # Store the clist to the cname key of the config registry
                        #assign_key_value("config_registry" "${cname}" "${clist}")
                        set(config_registry_${cname} "${clist}" PARENT_SCOPE)
                        list(APPEND config_registry_list "${cname}")
                    endif()
                endif()
                
                if(passnum EQUAL 1)
                    # Store the klist to the cname key of the kernel registry
                    #assign_key_value("kernel_registry" "${cname}" "${klist}")
                    set(kernel_registry_${cname} "${klist}" PARENT_SCOPE)
                    list(APPEND kernel_registry_list "${cname}")
                endif()
            else()
                # Umbrella configurations/families
                # First check if cname is blacklisted
                if(NOT "${cname}" IN_LIST all_blist)
                    if(passnum EQUAL 1)
                        # Check each item in the clist and klist and remove blacklisted ones
                        list(REMOVE_ITEM clist ${all_blist})
                        list(REMOVE_ITEM klist ${all_blist})

                        # Store the config and kernel lists

                        set(config_registry_${cname} "${clist}" PARENT_SCOPE)
                        set(kernel_registry_${cname} "${klist}" PARENT_SCOPE)
                        list(APPEND config_registry_list "${cname}")
                        list(APPEND kernel_registry_list "${cname}")
                    endif()
                endif()
            endif()
        endforeach()
    else()
        message(WARNING "Configuration registry file ${filename} does not exist")
    endif()
    
    if(passnum EQUAL 0)
        # Assign the final indirect blacklist
        set(indirect_blist "${indirect_blist}" PARENT_SCOPE)
    endif()
    
    # Remove duplicates and excess whitespace from the full config and kernel lists
    if(passnum EQUAL 1)
        list(REMOVE_DUPLICATES full_config_list)
        set(full_config_list "${full_config_list}" PARENT_SCOPE)

        list(REMOVE_DUPLICATES full_subconfig_list)
        set(full_subconfig_list "${full_subconfig_list}" PARENT_SCOPE)

        list(REMOVE_DUPLICATES full_kernel_list)
        set(full_kernel_list "${full_kernel_list}" PARENT_SCOPE)

        list(REMOVE_DUPLICATES config_registry_list)
        set(config_registry_list "${config_registry_list}" PARENT_SCOPE)
        list(REMOVE_DUPLICATES kernel_registry_list)
        set(kernel_registry_list "${kernel_registry_list}" PARENT_SCOPE)
    endif()

endfunction()

function(read_registry_file filename)

	# Execute an initial pass through the config_registry file so that
	# we can accumulate a list of indirectly blacklisted configurations,
	# if any.
	pass_config_kernel_registries("${filename}" 0)

	# Now that the indirect_blist has been created, make a second pass
	# through the 'config_registry' file, this time creating the actual
	# config and kernel registry data structures.
	pass_config_kernel_registries("${filename}" 1)

	# Now we must go back through the config_registry and subsitute any
	# configuration families with their constituents' members. Each time
	# one of these substitutions occurs, we set a flag that causes us to
	# make one more pass. (Subsituting a singleton definition does not
	# prompt additional iterations.) This process stops when a full pass
	# does not result in any subsitution.

	set(iterate_again 1)
	while (${iterate_again} EQUAL 1)

		set(iterate_again 0)

        foreach(config IN LISTS config_registry_list)
			# The entries that define singleton families should never need
			# any substitution.
			is_singleton(config_registry_${config} is_singleton_fam)
            if(is_singleton_fam)
                continue()
            endif()

			foreach(mem IN LISTS config_registry_${config})
				set(mems_mem_list "${config_registry_${mem}}")

				# If mems_mem is empty string, then mem was not found as a key
				# in the config list associative array. In that case, we continue
				# and will echo an error later in the script.
				if("${mems_mem_list}" STREQUAL "")
					continue()
				endif()

				if(NOT "${mem}" STREQUAL "${mems_mem_list}")

                    set(newclist "${config_registry_${config}}")
                    list(TRANSFORM newclist REPLACE "^${mem}$" "${mems_mem_list}")

                    # Remove duplicates from the new list
                    list(REMOVE_DUPLICATES newclist)

                    if(NOT "${mem}" IN_LIST mems_mem_list)
                        set(iterate_again 1)
                    endif()

                    # Update the config registry with the substituted list
                    set(config_registry_${config} "${newclist}")

                endif()
            endforeach()
        endforeach()
    endwhile()

	# Similar to what we just did for the config_registry, we now iterate
	# through the kernel_registry and substitute any configuration families
	# in the kernel list (right side of ':') with the members of that
	# family's kernel set. This process continues iteratively, as before,
	# until all families have been replaced with singleton configurations'
	# kernel sets.
	set(iterate_again 1)
	while(${iterate_again} EQUAL 1)

		set(iterate_again 0)

		#for config in "${!kernel_registry[@]}"; do
		foreach(config IN LISTS kernel_registry_list)

            set(klist "${kernel_registry_${config}}")

			# The entries that define singleton families should never need
			# any substitution. In the kernel registry, we know it's a
			# singleton entry when the cname occurs somewhere in the klist.
			# (This is slightly different than the same test in the config
			# registry, where we test that clist is one word and that
			# clist == cname.)
            if("${config}" IN_LIST klist)
                continue()
            endif()

			#for ker in ${kernel_registry[$config]}; do
			#for ker in ${!kr_var}; do
			foreach(ker IN LISTS klist)

				#kers_ker="${kernel_registry[${ker}]}"
				#kers_ker=$(query_array "kernel_registry" "${ker}")
                set(kers_ker "${kernel_registry_${ker}}")

				# If kers_ker is empty string, then ker was not found as a key
				# in the kernel registry. While not common, this can happen
				# when ker identifies a kernel set that does not correspond to
				# any configuration. (Example: armv7a and armv8a kernel sets are
				# used by cortexa* configurations, but do not corresond to their
				# own configurations.)
				if("${kers_ker}" STREQUAL "")
                    continue()
                endif()

				# If the current config/kernel (ker) differs from its singleton kernel
				# entry (kers_ker), then that singleton entry was specified to use
				# a different configuration's kernel set. Thus, we need to replace the
				# occurrence in the current config/kernel name with that of the kernel
				# set it needs.
				if(NOT "${ker}" STREQUAL "${kers_ker}")
                    set(newklist "${kernel_registry_${config}}")
                    list(TRANSFORM newklist REPLACE "^${ker}$" "${kers_ker}")

					# Replace the current config with its requisite kernels,
					# canonicalize whitespace, and then remove duplicate kernel
					# set names, if they exist. Finally, update the kernel registry
					# with the new kernel list.
					# NOTE: WE must use substitute_words() rather than a simple sed
					# expression because we need to avoid matching partial strings.
					# For example, if klist above contains "foo bar barsk" and we use
					# sed to substitute "bee boo" as the members of "bar", the
					# result would (incorrectly) be "foo bee boo bee boosk",
					# which would then get reduced, via rm_duplicate_words(), to
					# "foo bee boo boosk".
					#newklist=$(echo -e "${klisttmp}" | sed -e "s/${ker}/${kers_ker}/g")
					list(REMOVE_DUPLICATES newklist)


                    if(NOT "${config}" STREQUAL "firestorm")
                    set(kernel_registry_${config} "${newklist}")
                    endif()
                    if(NOT "${ker}" IN_LIST kers_ker)
                        set(iterate_again 1)
                    endif()

				endif()
			endforeach()
        endforeach()
	endwhile()
    set(config_registry "${config_registry}" PARENT_SCOPE)
    set(kernel_registry "${kernel_registry}" PARENT_SCOPE)
    set(full_config_list "${full_config_list}" PARENT_SCOPE)
    set(full_subconfig_list "${full_subconfig_list}" PARENT_SCOPE)
    set(full_kernel_list "${full_kernel_list}" PARENT_SCOPE)
    foreach(config IN LISTS config_registry_list)
        set(config_registry_${config} "${config_registry_${config}}" PARENT_SCOPE)
    endforeach()
    foreach(kernel IN LISTS kernel_registry_list)
        set(kernel_registry_${kernel} "${kernel_registry_${kernel}}" PARENT_SCOPE)
    endforeach()
endfunction()
