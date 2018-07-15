###
### Copyright 2015-2017 Oliver Giles
###
### This file is part of Laminar
###
### Laminar is free software: you can redistribute it and/or modify
### it under the terms of the GNU General Public License as published by
### the Free Software Foundation, either version 3 of the License, or
### (at your option) any later version.
###
### Laminar is distributed in the hope that it will be useful,
### but WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
### GNU General Public License for more details.
###
### You should have received a copy of the GNU General Public License
### along with Laminar.  If not, see <http://www.gnu.org/licenses/>
###
cmake_minimum_required(VERSION 3.5)
cmake_policy(SET CMP0058 NEW)

set(BUILD_TESTS FALSE CACHE BOOL "Build tests")
option (USE_SUPERBUILD "Whether or not a superbuild should be invoked" ON)

if (USE_SUPERBUILD)
  project (SUPERBUILD NONE)
  # execute the superbuild (this script will be invoked again without the
  # USE_SUPERBUILD option this time)
  include (external.cmake)
  return()
else()
  project(laminar)
endif()


set(CMAKE_INCLUDE_CURRENT_DIR ON)

add_definitions("-std=c++11 -Wall -Wextra -Wno-unused-parameter -Wno-sign-compare")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -Werror -DDEBUG")

# This macro takes a list of files, gzips them and converts the output into
# object files so they can be linked directly into the application.
# ld generates symbols based on the string argument given to its executable,
# so it is significant from which directory it is called. BASEDIR will be
# removed from the beginning of paths to the remaining arguments
macro(generate_compressed_bins BASEDIR)
    foreach(FILE ${ARGN})
        set(COMPRESSED_FILE "${FILE}.z")
        set(OUTPUT_FILE "${FILE}.o")
        get_filename_component(DIR ${FILE} PATH)
        if(DIR)
            file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${DIR})
        endif()
        add_custom_command(OUTPUT ${COMPRESSED_FILE}
            COMMAND gzip < ${BASEDIR}/${FILE} > ${COMPRESSED_FILE}
            DEPENDS ${BASEDIR}/${FILE}
        )
        add_custom_command(OUTPUT ${OUTPUT_FILE}
            COMMAND ld -r -b binary -o ${OUTPUT_FILE} ${COMPRESSED_FILE}
            DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${COMPRESSED_FILE}
        )
        list(APPEND COMPRESSED_BINS ${OUTPUT_FILE})
    endforeach()
endmacro()

# Same purpose as previous macro but do not compress content.
# Index page is embedded uncompressed. laminard will change base href at
# runtime to permit relocation behind web reverse proxy.
macro(generate_bins BASEDIR)
    foreach(FILE ${ARGN})
        set(OUTPUT_FILE "${FILE}.o")
        get_filename_component(DIR ${FILE} PATH)
        if(DIR)
            file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${DIR})
        endif()
        add_custom_command(OUTPUT ${OUTPUT_FILE}
            # Copy resource to build dir to have simple symbol name
            COMMAND cp -f ${BASEDIR}/${FILE} ${FILE}
            COMMAND ld -r -b binary -o ${OUTPUT_FILE} ${FILE}
            DEPENDS ${BASEDIR}/${FILE}
        )
    list(APPEND RESOURCES_BINS ${OUTPUT_FILE})
    endforeach()
endmacro()

# Compile index page resources
generate_bins(${CMAKE_SOURCE_DIR}/src/resources head.html body.html)

# Zip and compile statically served resources
generate_compressed_bins(${CMAKE_SOURCE_DIR}/src/resources js/app.js
    favicon.ico favicon-152.png icon.png)

# Download 3rd-party frontend JS libs...
file(DOWNLOAD https://cdnjs.cloudflare.com/ajax/libs/vue/2.3.4/vue.min.js
        js/vue.min.js EXPECTED_MD5 ae2fca1cfa0e31377819b1b0ffef704c)
file(DOWNLOAD https://cdnjs.cloudflare.com/ajax/libs/vue-router/2.7.0/vue-router.min.js
        js/vue-router.min.js EXPECTED_MD5 5d3e35710dbe02de78c39e3e439b8d4e)
file(DOWNLOAD https://raw.githubusercontent.com/drudru/ansi_up/v1.3.0/ansi_up.js
        js/ansi_up.js EXPECTED_MD5 158566dc1ff8f2804de972f7e841e2f6)
file(DOWNLOAD https://cdnjs.cloudflare.com/ajax/libs/Chart.js/1.0.2/Chart.min.js
        js/Chart.min.js EXPECTED_MD5 0d3004601c1a855a3d203502549528a7)
file(DOWNLOAD https://raw.githubusercontent.com/tomsouthall/Chart.HorizontalBar.js/v1.04/Chart.HorizontalBar.js
        js/Chart.HorizontalBar.js EXPECTED_MD5 95070a38e69bc56534e1b2086d985270)
file(DOWNLOAD https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css
        css/bootstrap.min.css EXPECTED_MD5 5d5357cb3704e1f43a1f5bfed2aebf42)
# ...and compile them
generate_compressed_bins(${CMAKE_BINARY_DIR} js/vue-router.min.js js/vue.min.js
    js/ansi_up.js js/Chart.min.js js/Chart.HorizontalBar.js css/bootstrap.min.css)
# (see resources.cpp where these are fetched)

find_package(CapnProto CONFIG REQUIRED)

# Generates Cap'n Proto interface from definition file
set(CAPNPC_SRC_PREFIX "${CMAKE_CURRENT_SOURCE_DIR}/src")
capnp_generate_cpp(CAPNP_SRCS CAPNP_HDRS src/laminar.capnp)

## Server
add_executable(laminard src/database.cpp src/main.cpp src/server.cpp src/laminar.cpp
    src/conf.cpp src/resources.cpp src/run.cpp ${CAPNP_SRCS} ${COMPRESSED_BINS}
    ${RESOURCES_BINS})
# TODO: some alternative to boost::filesystem?
target_link_libraries(laminard PRIVATE CapnProto::capnp-rpc PRIVATE CapnProto::capnp
    PRIVATE CapnProto::kj PRIVATE CapnProto::kj-async
    boost_filesystem boost_system sqlite3 z)

## Client
add_executable(laminarc src/client.cpp ${CAPNP_SRCS})
target_link_libraries(laminarc PRIVATE CapnProto::capnp-rpc PRIVATE CapnProto::capnp
    PRIVATE CapnProto::kj PRIVATE CapnProto::kj-async)

## Tests
if(BUILD_TESTS)
    find_package(GTest REQUIRED)
    find_library(GMOCK_LIBRARY
        NAMES gmock
        HINTS ENV GMOCK_ROOT ${GMOCK_ROOT} ENV GTEST_ROOT ${GTEST_ROOT}
        PATH_SUFFIXES . lib
        )
    include_directories(${GTEST_INCLUDE_DIRS} src)
    add_executable(laminar-tests src/conf.cpp src/database.cpp src/laminar.cpp src/run.cpp src/server.cpp ${CAPNP_SRCS} src/resources.cpp ${COMPRESSED_BINS} ${RESOURCES_BINS} test/test-conf.cpp test/test-database.cpp test/test-laminar.cpp test/test-run.cpp test/test-server.cpp)
    target_link_libraries(laminar-tests
        PRIVATE CapnProto::capnp-rpc PRIVATE CapnProto::capnp
        PRIVATE CapnProto::kj PRIVATE CapnProto::kj-async
        ${GTEST_BOTH_LIBRARIES} ${GMOCK_LIBRARY}
        boost_filesystem boost_system sqlite3 z)
endif()

set(SYSTEMD_UNITDIR /lib/systemd/system CACHE PATH "Path to systemd unit files")
install(TARGETS laminard laminarc RUNTIME DESTINATION usr/bin)
install(FILES laminar.service DESTINATION ${SYSTEMD_UNITDIR})
install(FILES laminar.conf DESTINATION etc)
