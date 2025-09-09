if(
    NOT DEFINED ROOT
    OR NOT DEFINED ARCH
)
    message(
        FATAL_ERROR
        "Assert: ROOT = ${ROOT}; ARCH = ${ARCH}"
    )
endif()

# Enforce 64-bit builds only
if(NOT ARCH STREQUAL "amd64")
    message(
        FATAL_ERROR
        "Only amd64 builds are supported by these scripts. ARCH = ${ARCH}"
    )
endif()

set(
    PROJECT_ROOT_PATH
    "${CMAKE_CURRENT_LIST_DIR}/.."
)

set(
    ROGII_FOLDER_PATH
    "${CMAKE_CURRENT_LIST_DIR}"
)

if(NOT DEFINED GIT_COMMIT)
    set(
        GIT_COMMIT
        000000
    )

    if(DEFINED ENV{GIT_COMMIT})
        set(
            GIT_COMMIT
            $ENV{GIT_COMMIT}
        )
    else()
        find_package(Git)
        if(Git_FOUND)
            execute_process(
                COMMAND
                    ${GIT_EXECUTABLE} rev-parse --short HEAD
                OUTPUT_VARIABLE
                    GIT_COMMIT
                OUTPUT_STRIP_TRAILING_WHITESPACE
                WORKING_DIRECTORY
                    ${PROJECT_ROOT_PATH}
            )
        endif()
    endif()
endif()

set(
    TAG
    ""
)

if(DEFINED ENV{TAG})
    set(
        TAG
        "$ENV{TAG}"
    )
else()
    set(
        TAG
        "_${GIT_COMMIT}"
    )
endif()

# Read SQLite version from VERSION file
file(READ "${PROJECT_ROOT_PATH}/VERSION" SQLITE_VERSION_STR)
string(STRIP "${SQLITE_VERSION_STR}" SQLITE_VERSION_STR)

# Build number may be provided externally; default to 0
if(NOT DEFINED BUILD_NUMBER)
    if(DEFINED ENV{BUILD_NUMBER})
        set(
            BUILD_NUMBER
            $ENV{BUILD_NUMBER}
        )
    else()
        set(
            BUILD_NUMBER
            0
        )
    endif()
endif()

set(
    PACKAGE_NAME
    "sqlite-${SQLITE_VERSION_STR}-${ARCH}-${BUILD_NUMBER}${TAG}"
)

# Per-config build and staging directories
set(
    DEBUG_PATH
    "${PROJECT_ROOT_PATH}/build/debug_${ARCH}"
)
set(
    RELEASE_PATH
    "${PROJECT_ROOT_PATH}/build/release_${ARCH}"
)
file(MAKE_DIRECTORY "${DEBUG_PATH}")
file(MAKE_DIRECTORY "${RELEASE_PATH}")

set(
    STAGE_BIN
    "${RELEASE_PATH}/bin"
)
set(
    STAGE_INCLUDE
    "${RELEASE_PATH}/include"
)
file(MAKE_DIRECTORY "${STAGE_BIN}")
file(MAKE_DIRECTORY "${STAGE_INCLUDE}")

# Build SQLite depending on the host platform (script mode may not set compiler id)
if(WIN32)
    execute_process(
        COMMAND
            nmake /f Makefile.msc clean
        WORKING_DIRECTORY
            "${PROJECT_ROOT_PATH}"
        RESULT_VARIABLE
            NMAKE_CLEAN_RESULT
    )
    if(NOT NMAKE_CLEAN_RESULT EQUAL 0)
        message(WARNING "nmake clean failed with code ${NMAKE_CLEAN_RESULT}")
    endif()

    execute_process(
        COMMAND
            nmake /f Makefile.msc sqlite3.dll libsqlite3.lib sqlite3.exe sqlite3.h
        WORKING_DIRECTORY
            "${PROJECT_ROOT_PATH}"
        RESULT_VARIABLE
            NMAKE_RESULT
    )
    if(NOT NMAKE_RESULT EQUAL 0)
        message(
            FATAL_ERROR
            "nmake build failed with code ${NMAKE_RESULT}"
        )
    endif()

    # Build Release (default)
    foreach(_f sqlite3.dll sqlite3.exe sqlite3.lib libsqlite3.lib)
        if(EXISTS "${PROJECT_ROOT_PATH}/${_f}")
            file(
                COPY
                    "${PROJECT_ROOT_PATH}/${_f}"
                DESTINATION
                    "${STAGE_BIN}"
            )
        endif()
    endforeach()
    file(
        COPY
            "${PROJECT_ROOT_PATH}/sqlite3.h"
        DESTINATION
            "${STAGE_INCLUDE}"
    )

    # Build Debug
    execute_process(
        COMMAND
            nmake /f Makefile.msc clean
        WORKING_DIRECTORY
            "${PROJECT_ROOT_PATH}"
        RESULT_VARIABLE
            NMAKE_CLEAN_RESULT2
    )
    if(NOT NMAKE_CLEAN_RESULT2 EQUAL 0)
        message(WARNING "nmake clean (for debug) failed with code ${NMAKE_CLEAN_RESULT2}")
    endif()

    execute_process(
        COMMAND
            nmake /f Makefile.msc DEBUG=1 sqlite3.dll libsqlite3.lib sqlite3.exe sqlite3.h
        WORKING_DIRECTORY
            "${PROJECT_ROOT_PATH}"
        RESULT_VARIABLE
            NMAKE_RESULT_DBG
    )
    if(NOT NMAKE_RESULT_DBG EQUAL 0)
        message(
            FATAL_ERROR
            "nmake build (debug) failed with code ${NMAKE_RESULT_DBG}"
        )
    endif()

    # Copy debug libraries with 'd' suffix into common bin
    if(EXISTS "${PROJECT_ROOT_PATH}/sqlite3.dll")
        execute_process(
            COMMAND
                "${CMAKE_COMMAND}" -E copy
                "${PROJECT_ROOT_PATH}/sqlite3.dll"
                "${STAGE_BIN}/sqlite3d.dll"
        )
    endif()
    if(EXISTS "${PROJECT_ROOT_PATH}/sqlite3.lib")
        execute_process(
            COMMAND
                "${CMAKE_COMMAND}" -E copy
                "${PROJECT_ROOT_PATH}/sqlite3.lib"
                "${STAGE_BIN}/sqlite3d.lib"
        )
    endif()
elseif(UNIX)
    # Release out-of-tree
    execute_process(
        COMMAND
            ../../configure --enable-all
        WORKING_DIRECTORY
            "${RELEASE_PATH}"
        RESULT_VARIABLE
            CONFIGURE_RESULT_REL
    )
    if(NOT CONFIGURE_RESULT_REL EQUAL 0)
        message(
            FATAL_ERROR
            "configure (release) failed with code ${CONFIGURE_RESULT_REL}"
        )
    endif()

    execute_process(
        COMMAND
            make -j sqlite3 libsqlite3.so sqlite3.h
        WORKING_DIRECTORY
            "${RELEASE_PATH}"
        RESULT_VARIABLE
            MAKE_RESULT_REL
    )
    if(NOT MAKE_RESULT_REL EQUAL 0)
        message(
            FATAL_ERROR
            "make (release) failed with code ${MAKE_RESULT_REL}"
        )
    endif()

    if(EXISTS "${RELEASE_PATH}/sqlite3")
        file(COPY "${RELEASE_PATH}/sqlite3" DESTINATION "${STAGE_BIN}")
    endif()
    if(EXISTS "${RELEASE_PATH}/libsqlite3.so")
        file(COPY "${RELEASE_PATH}/libsqlite3.so" DESTINATION "${STAGE_BIN}")
    endif()
    if(EXISTS "${RELEASE_PATH}/sqlite3.h")
        file(COPY "${RELEASE_PATH}/sqlite3.h" DESTINATION "${STAGE_INCLUDE}")
    endif()

    # Debug out-of-tree
    execute_process(
        COMMAND
            sh -c "CFLAGS='-O0 -g' ../../configure --enable-all"
        WORKING_DIRECTORY
            "${DEBUG_PATH}"
        RESULT_VARIABLE
            CONFIGURE_RESULT_DBG
    )
    if(NOT CONFIGURE_RESULT_DBG EQUAL 0)
        message(
            FATAL_ERROR
            "configure (debug) failed with code ${CONFIGURE_RESULT_DBG}"
        )
    endif()

    execute_process(
        COMMAND
            make -j sqlite3 libsqlite3.so
        WORKING_DIRECTORY
            "${DEBUG_PATH}"
        RESULT_VARIABLE
            MAKE_RESULT_DBG
    )
    if(NOT MAKE_RESULT_DBG EQUAL 0)
        message(
            FATAL_ERROR
            "make (debug) failed with code ${MAKE_RESULT_DBG}"
        )
    endif()

    if(EXISTS "${DEBUG_PATH}/libsqlite3.so")
        execute_process(
            COMMAND
                "${CMAKE_COMMAND}" -E copy
                "${DEBUG_PATH}/libsqlite3.so"
                "${STAGE_BIN}/libsqlite3d.so"
        )
    endif()
else()
    message(
        FATAL_ERROR
        "Unsupported host platform for SQLite build. Expected WIN32 or UNIX."
    )
endif()

# Package layout: bin/include/src + package.cmake
# Copy staged files into package structure
file(
    COPY
        "${STAGE_INCLUDE}"
        "${ROGII_FOLDER_PATH}/package.cmake"
    DESTINATION
        "${ROOT}/${PACKAGE_NAME}"
)

file(MAKE_DIRECTORY "${ROOT}/${PACKAGE_NAME}/bin")
file(
    COPY
        "${STAGE_BIN}/"
    DESTINATION
        "${ROOT}/${PACKAGE_NAME}/bin"
)

execute_process(
    COMMAND
        "${CMAKE_COMMAND}" -E tar cf "${PACKAGE_NAME}.7z" --format=7zip -- "${PACKAGE_NAME}"
    WORKING_DIRECTORY
        "${ROOT}"
)

