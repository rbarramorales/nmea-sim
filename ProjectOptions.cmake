include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(nmea_sim_supports_sanitizers)
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

macro(nmea_sim_setup_options)
  option(nmea_sim_ENABLE_HARDENING "Enable hardening" ON)
  option(nmea_sim_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    nmea_sim_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    nmea_sim_ENABLE_HARDENING
    OFF)

  nmea_sim_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR nmea_sim_PACKAGING_MAINTAINER_MODE)
    option(nmea_sim_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(nmea_sim_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(nmea_sim_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(nmea_sim_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(nmea_sim_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(nmea_sim_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(nmea_sim_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(nmea_sim_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(nmea_sim_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(nmea_sim_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(nmea_sim_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(nmea_sim_ENABLE_PCH "Enable precompiled headers" OFF)
    option(nmea_sim_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(nmea_sim_ENABLE_IPO "Enable IPO/LTO" ON)
    option(nmea_sim_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(nmea_sim_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(nmea_sim_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(nmea_sim_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(nmea_sim_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(nmea_sim_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(nmea_sim_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(nmea_sim_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(nmea_sim_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(nmea_sim_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(nmea_sim_ENABLE_PCH "Enable precompiled headers" OFF)
    option(nmea_sim_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      nmea_sim_ENABLE_IPO
      nmea_sim_WARNINGS_AS_ERRORS
      nmea_sim_ENABLE_USER_LINKER
      nmea_sim_ENABLE_SANITIZER_ADDRESS
      nmea_sim_ENABLE_SANITIZER_LEAK
      nmea_sim_ENABLE_SANITIZER_UNDEFINED
      nmea_sim_ENABLE_SANITIZER_THREAD
      nmea_sim_ENABLE_SANITIZER_MEMORY
      nmea_sim_ENABLE_UNITY_BUILD
      nmea_sim_ENABLE_CLANG_TIDY
      nmea_sim_ENABLE_CPPCHECK
      nmea_sim_ENABLE_COVERAGE
      nmea_sim_ENABLE_PCH
      nmea_sim_ENABLE_CACHE)
  endif()

  nmea_sim_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (nmea_sim_ENABLE_SANITIZER_ADDRESS OR nmea_sim_ENABLE_SANITIZER_THREAD OR nmea_sim_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(nmea_sim_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(nmea_sim_global_options)
  if(nmea_sim_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    nmea_sim_enable_ipo()
  endif()

  nmea_sim_supports_sanitizers()

  if(nmea_sim_ENABLE_HARDENING AND nmea_sim_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR nmea_sim_ENABLE_SANITIZER_UNDEFINED
       OR nmea_sim_ENABLE_SANITIZER_ADDRESS
       OR nmea_sim_ENABLE_SANITIZER_THREAD
       OR nmea_sim_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${nmea_sim_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${nmea_sim_ENABLE_SANITIZER_UNDEFINED}")
    nmea_sim_enable_hardening(nmea_sim_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(nmea_sim_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(nmea_sim_warnings INTERFACE)
  add_library(nmea_sim_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  nmea_sim_set_project_warnings(
    nmea_sim_warnings
    ${nmea_sim_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(nmea_sim_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(nmea_sim_options)
  endif()

  include(cmake/Sanitizers.cmake)
  nmea_sim_enable_sanitizers(
    nmea_sim_options
    ${nmea_sim_ENABLE_SANITIZER_ADDRESS}
    ${nmea_sim_ENABLE_SANITIZER_LEAK}
    ${nmea_sim_ENABLE_SANITIZER_UNDEFINED}
    ${nmea_sim_ENABLE_SANITIZER_THREAD}
    ${nmea_sim_ENABLE_SANITIZER_MEMORY})

  set_target_properties(nmea_sim_options PROPERTIES UNITY_BUILD ${nmea_sim_ENABLE_UNITY_BUILD})

  if(nmea_sim_ENABLE_PCH)
    target_precompile_headers(
      nmea_sim_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(nmea_sim_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    nmea_sim_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(nmea_sim_ENABLE_CLANG_TIDY)
    nmea_sim_enable_clang_tidy(nmea_sim_options ${nmea_sim_WARNINGS_AS_ERRORS})
  endif()

  if(nmea_sim_ENABLE_CPPCHECK)
    nmea_sim_enable_cppcheck(${nmea_sim_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(nmea_sim_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    nmea_sim_enable_coverage(nmea_sim_options)
  endif()

  if(nmea_sim_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(nmea_sim_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(nmea_sim_ENABLE_HARDENING AND NOT nmea_sim_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR nmea_sim_ENABLE_SANITIZER_UNDEFINED
       OR nmea_sim_ENABLE_SANITIZER_ADDRESS
       OR nmea_sim_ENABLE_SANITIZER_THREAD
       OR nmea_sim_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    nmea_sim_enable_hardening(nmea_sim_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
