

set(CMAKE_C_COMPILER_ID "GNU")
set(CMAKE_C_COMPILER_VERSION "15.1.0")

include(cmake/BlacklistConfigs.cmake)



GetBlacklistedConfigs()


include(cmake/ReadConfigRegistry.cmake)


read_registry_file("${CMAKE_SOURCE_DIR}/config_registry")


message(STATUS "config_registry: ${config_registry}")
message(STATUS "config_blist: ${config_blist}")
message(STATUS "full_config_list: ${full_config_list}")
message(STATUS "full_subconfig_list: ${full_subconfig_list}")
message(STATUS "full_kernel_list: ${full_kernel_list}")

message(STATUS "config_registry_x86_64: ${config_registry_x86_64}")
message(STATUS "kernel_registry_x86_64: ${kernel_registry_x86_64}")

message(STATUS "config_registry_firestorm: ${config_registry_firestorm}")
message(STATUS "kernel_registry_firestorm: ${kernel_registry_firestorm}")