include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(s_vpn_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(s_vpn_setup_options)
  option(s_vpn_ENABLE_HARDENING "Enable hardening" ON)
  option(s_vpn_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    s_vpn_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    s_vpn_ENABLE_HARDENING
    OFF)

  s_vpn_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR s_vpn_PACKAGING_MAINTAINER_MODE)
    option(s_vpn_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(s_vpn_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(s_vpn_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(s_vpn_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(s_vpn_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(s_vpn_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(s_vpn_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(s_vpn_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(s_vpn_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(s_vpn_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(s_vpn_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(s_vpn_ENABLE_PCH "Enable precompiled headers" OFF)
    option(s_vpn_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(s_vpn_ENABLE_IPO "Enable IPO/LTO" ON)
    option(s_vpn_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(s_vpn_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(s_vpn_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(s_vpn_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(s_vpn_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(s_vpn_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(s_vpn_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(s_vpn_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(s_vpn_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(s_vpn_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(s_vpn_ENABLE_PCH "Enable precompiled headers" OFF)
    option(s_vpn_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      s_vpn_ENABLE_IPO
      s_vpn_WARNINGS_AS_ERRORS
      s_vpn_ENABLE_USER_LINKER
      s_vpn_ENABLE_SANITIZER_ADDRESS
      s_vpn_ENABLE_SANITIZER_LEAK
      s_vpn_ENABLE_SANITIZER_UNDEFINED
      s_vpn_ENABLE_SANITIZER_THREAD
      s_vpn_ENABLE_SANITIZER_MEMORY
      s_vpn_ENABLE_UNITY_BUILD
      s_vpn_ENABLE_CLANG_TIDY
      s_vpn_ENABLE_CPPCHECK
      s_vpn_ENABLE_COVERAGE
      s_vpn_ENABLE_PCH
      s_vpn_ENABLE_CACHE)
  endif()

  s_vpn_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (s_vpn_ENABLE_SANITIZER_ADDRESS OR s_vpn_ENABLE_SANITIZER_THREAD OR s_vpn_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(s_vpn_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(s_vpn_global_options)
  if(s_vpn_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    s_vpn_enable_ipo()
  endif()

  s_vpn_supports_sanitizers()

  if(s_vpn_ENABLE_HARDENING AND s_vpn_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR s_vpn_ENABLE_SANITIZER_UNDEFINED
       OR s_vpn_ENABLE_SANITIZER_ADDRESS
       OR s_vpn_ENABLE_SANITIZER_THREAD
       OR s_vpn_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${s_vpn_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${s_vpn_ENABLE_SANITIZER_UNDEFINED}")
    s_vpn_enable_hardening(s_vpn_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(s_vpn_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(s_vpn_warnings INTERFACE)
  add_library(s_vpn_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  s_vpn_set_project_warnings(
    s_vpn_warnings
    ${s_vpn_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(s_vpn_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    s_vpn_configure_linker(s_vpn_options)
  endif()

  include(cmake/Sanitizers.cmake)
  s_vpn_enable_sanitizers(
    s_vpn_options
    ${s_vpn_ENABLE_SANITIZER_ADDRESS}
    ${s_vpn_ENABLE_SANITIZER_LEAK}
    ${s_vpn_ENABLE_SANITIZER_UNDEFINED}
    ${s_vpn_ENABLE_SANITIZER_THREAD}
    ${s_vpn_ENABLE_SANITIZER_MEMORY})

  set_target_properties(s_vpn_options PROPERTIES UNITY_BUILD ${s_vpn_ENABLE_UNITY_BUILD})

  if(s_vpn_ENABLE_PCH)
    target_precompile_headers(
      s_vpn_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(s_vpn_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    s_vpn_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(s_vpn_ENABLE_CLANG_TIDY)
    s_vpn_enable_clang_tidy(s_vpn_options ${s_vpn_WARNINGS_AS_ERRORS})
  endif()

  if(s_vpn_ENABLE_CPPCHECK)
    s_vpn_enable_cppcheck(${s_vpn_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(s_vpn_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    s_vpn_enable_coverage(s_vpn_options)
  endif()

  if(s_vpn_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(s_vpn_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(s_vpn_ENABLE_HARDENING AND NOT s_vpn_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR s_vpn_ENABLE_SANITIZER_UNDEFINED
       OR s_vpn_ENABLE_SANITIZER_ADDRESS
       OR s_vpn_ENABLE_SANITIZER_THREAD
       OR s_vpn_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    s_vpn_enable_hardening(s_vpn_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
