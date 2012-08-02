# - Find bison executable and provides macros to generate custom build rules
# The module defines the following variables:
#
#  BISON_EXECUTABLE - path to the bison program
#  BISON_VERSION - version of bison
#  BISON_FOUND - true if the program was found
#
# The minimum required version of bison can be specified using the
# standard CMake syntax, e.g. find_package(BISON 2.1.3)
#
# If bison is found, the module defines the macros:
#  BISON_TARGET(<Name> <YaccInput> <CodeOutput> [VERBOSE <file>]
#              [COMPILE_FLAGS <string>])
# which will create  a custom rule to generate  a parser. <YaccInput> is
# the path to  a yacc file. <CodeOutput> is the name  of the source file
# generated by bison.  A header file is also  be generated, and contains
# the  token  list.  If  COMPILE_FLAGS  option is  specified,  the  next
# parameter is  added in the bison  command line.  if  VERBOSE option is
# specified, <file> is created  and contains verbose descriptions of the
# grammar and parser. The macro defines a set of variables:
#  BISON_${Name}_DEFINED - true is the macro ran successfully
#  BISON_${Name}_INPUT - The input source file, an alias for <YaccInput>
#  BISON_${Name}_OUTPUT_SOURCE - The source file generated by bison
#  BISON_${Name}_OUTPUT_HEADER - The header file generated by bison
#  BISON_${Name}_OUTPUTS - The sources files generated by bison
#  BISON_${Name}_COMPILE_FLAGS - Options used in the bison command line
#
#  ====================================================================
#  Example:
#
#   find_package(BISON)
#   BISON_TARGET(MyParser parser.y ${CMAKE_CURRENT_BINARY_DIR}/parser.cpp)
#   add_executable(Foo main.cpp ${BISON_MyParser_OUTPUTS})
#  ====================================================================

#=============================================================================
# Copyright 2009 Kitware, Inc.
# Copyright 2006 Tristan Carel
#
# Distributed under the OSI-approved BSD License (the "License");
# see accompanying file Copyright.txt for details.
#
# This software is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the License for more information.
#=============================================================================
# (To distribute this file outside of CMake, substitute the full
#  License text for the above reference.)

FIND_PROGRAM(BISON_EXECUTABLE bison DOC "path to the bison executable")
MARK_AS_ADVANCED(BISON_EXECUTABLE)

IF(BISON_EXECUTABLE)

  EXECUTE_PROCESS(COMMAND ${BISON_EXECUTABLE} --version
    OUTPUT_VARIABLE BISON_version_output
    ERROR_VARIABLE BISON_version_error
    RESULT_VARIABLE BISON_version_result
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  IF(NOT ${BISON_version_result} EQUAL 0)
    MESSAGE(SEND_ERROR "Command \"${BISON_EXECUTABLE} --version\" failed with output:\n${BISON_version_error}")
  ELSE()
    STRING(REGEX REPLACE "^bison \\(GNU Bison\\) ([^\n]+)\n.*" "\\1"
      BISON_VERSION "${BISON_version_output}")
  ENDIF()

  # internal macro
  MACRO(BISON_TARGET_option_verbose Name BisonOutput filename)
    LIST(APPEND BISON_TARGET_cmdopt "--verbose")
    GET_FILENAME_COMPONENT(BISON_TARGET_output_path "${BisonOutput}" PATH)
    GET_FILENAME_COMPONENT(BISON_TARGET_output_name "${BisonOutput}" NAME_WE)
    ADD_CUSTOM_COMMAND(OUTPUT ${filename}
      COMMAND ${CMAKE_COMMAND}
      ARGS -E copy
      "${BISON_TARGET_output_path}/${BISON_TARGET_output_name}.output"
      "${filename}"
      DEPENDS
      "${BISON_TARGET_output_path}/${BISON_TARGET_output_name}.output"
      COMMENT "[BISON][${Name}] Copying bison verbose table to ${filename}"
      WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
    SET(BISON_${Name}_VERBOSE_FILE ${filename})
    LIST(APPEND BISON_TARGET_extraoutputs
      "${BISON_TARGET_output_path}/${BISON_TARGET_output_name}.output")
  ENDMACRO(BISON_TARGET_option_verbose)

  # internal macro
  MACRO(BISON_TARGET_option_extraopts Options)
    SET(BISON_TARGET_extraopts "${Options}")
    SEPARATE_ARGUMENTS(BISON_TARGET_extraopts)
    LIST(APPEND BISON_TARGET_cmdopt ${BISON_TARGET_extraopts})
  ENDMACRO(BISON_TARGET_option_extraopts)

  #============================================================
  # BISON_TARGET (public macro)
  #============================================================
  #
  MACRO(BISON_TARGET Name BisonInput BisonOutput)
    SET(BISON_TARGET_output_header "")
    SET(BISON_TARGET_cmdopt "")
    SET(BISON_TARGET_outputs "${BisonOutput}")
    IF(NOT ${ARGC} EQUAL 3 AND NOT ${ARGC} EQUAL 5 AND NOT ${ARGC} EQUAL 7)
      MESSAGE(SEND_ERROR "Usage")
    ELSE()
      # Parsing parameters
      IF(${ARGC} GREATER 5 OR ${ARGC} EQUAL 5)
        IF("${ARGV3}" STREQUAL "VERBOSE")
          BISON_TARGET_option_verbose(${Name} ${BisonOutput} "${ARGV4}")
        ENDIF()
        IF("${ARGV3}" STREQUAL "COMPILE_FLAGS")
          BISON_TARGET_option_extraopts("${ARGV4}")
        ENDIF()
      ENDIF()

      IF(${ARGC} EQUAL 7)
        IF("${ARGV5}" STREQUAL "VERBOSE")
          BISON_TARGET_option_verbose(${Name} ${BisonOutput} "${ARGV6}")
        ENDIF()
      
        IF("${ARGV5}" STREQUAL "COMPILE_FLAGS")
          BISON_TARGET_option_extraopts("${ARGV6}")
        ENDIF()
      ENDIF()

      # Header's name generated by bison (see option -d)
      LIST(APPEND BISON_TARGET_cmdopt "-d")
      STRING(REGEX REPLACE "^(.*)(\\.[^.]*)$" "\\2" _fileext "${ARGV2}")
      STRING(REPLACE "c" "h" _fileext ${_fileext})
      STRING(REGEX REPLACE "^(.*)(\\.[^.]*)$" "\\1${_fileext}" 
          BISON_${Name}_OUTPUT_HEADER "${ARGV2}")
      LIST(APPEND BISON_TARGET_outputs "${BISON_${Name}_OUTPUT_HEADER}")
        
      ADD_CUSTOM_COMMAND(OUTPUT ${BISON_TARGET_outputs}
        ${BISON_TARGET_extraoutputs}
        COMMAND ${BISON_EXECUTABLE}
        ARGS ${BISON_TARGET_cmdopt} -o ${ARGV2} ${ARGV1}
        DEPENDS ${ARGV1}
        COMMENT "[BISON][${Name}] Building parser with bison ${BISON_VERSION}"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
    
      # define target variables
      SET(BISON_${Name}_DEFINED TRUE)
      SET(BISON_${Name}_INPUT ${ARGV1})
      SET(BISON_${Name}_OUTPUTS ${BISON_TARGET_outputs})
      SET(BISON_${Name}_COMPILE_FLAGS ${BISON_TARGET_cmdopt})
      SET(BISON_${Name}_OUTPUT_SOURCE "${BisonOutput}")

    ENDIF(NOT ${ARGC} EQUAL 3 AND NOT ${ARGC} EQUAL 5 AND NOT ${ARGC} EQUAL 7)
  ENDMACRO(BISON_TARGET)
  #
  #============================================================

ENDIF(BISON_EXECUTABLE)

INCLUDE("${CMAKE_SOURCE_DIR}/CMake/2.8/FindPackageHandleStandardArgs.cmake")
FIND_PACKAGE_HANDLE_STANDARD_ARGS(BISON REQUIRED_VARS  BISON_EXECUTABLE
                                        VERSION_VAR BISON_VERSION)

# FindBISON.cmake ends here
