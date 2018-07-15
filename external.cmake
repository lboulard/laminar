include(ExternalProject)

set_property (DIRECTORY PROPERTY EP_BASE external)

set (DEPENDENCIES)
set (EXTRA_CMAKE_ARGS)

# GoogleTest/GoogleMock
list (APPEND DEPENDENCIES gtest)
ExternalProject_Add(
    gtest
    DOWNLOAD_NAME googletest.tar.gz
    URL https://github.com/google/googletest/archive/release-1.8.0.tar.gz
    CMAKE_ARGS "-DCMAKE_INSTALL_PREFIX:PATH=${CMAKE_CURRENT_BINARY_DIR}/external/Install/gtest"
    )
ExternalProject_Get_Property(gtest INSTALL_DIR)

list (APPEND EXTRA_CMAKE_ARGS
    "-DGTEST_ROOT=${INSTALL_DIR}"
    )

# CapnProto
list (APPEND DEPENDENCIES capnproto)
ExternalProject_Add(
    capnproto
    DOWNLOAD_NAME capnproto.tar.gz
    URL https://github.com/capnproto/capnproto/archive/3079784bfaf3ba05edacfc63d6d494b76a85a3a5.tar.gz
    URL_HASH MD5=c5c04c1892a381e30bd032a6bceef111
    CMAKE_ARGS "-DCMAKE_INSTALL_PREFIX:PATH=${CMAKE_CURRENT_BINARY_DIR}/external/Install/capnproto"
        -DCMAKE_BUILD_TYPE=Release
        -DBUILD_TESTING=OFF
    )
ExternalProject_Get_Property(capnproto INSTALL_DIR)

list (APPEND EXTRA_CMAKE_ARGS
    "-DCapnProto_DIR:PATH=${INSTALL_DIR}/lib/cmake/CapnProto"
    )

ExternalProject_Add(rebuild
    DEPENDS ${DEPENDENCIES}
    SOURCE_DIR ${PROJECT_SOURCE_DIR}
    CMAKE_ARGS -DUSE_SUPERBUILD=OFF -DBUILD_TESTS=${BUILD_TESTS} ${EXTRA_CMAKE_ARGS}
    INSTALL_COMMAND ""
    BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR})
