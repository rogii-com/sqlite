set(
    COMPONENT_NAMES

    CNPM_RUNTIME_sqlite
    CNPM_RUNTIME
)

if(NOT TARGET SQLite::SQLite3)
    add_library(SQLite::SQLite3 SHARED IMPORTED)
    set_target_properties(
        SQLite::SQLite3
        PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES
                ${CMAKE_CURRENT_LIST_DIR}/include
    )
    if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        set_target_properties(
            SQLite::SQLite3
            PROPERTIES
                IMPORTED_LOCATION
                    ${CMAKE_CURRENT_LIST_DIR}/bin/sqlite3.dll
                IMPORTED_IMPLIB
                    ${CMAKE_CURRENT_LIST_DIR}/bin/sqlite3.lib
                IMPORTED_LOCATION_DEBUG
                    ${CMAKE_CURRENT_LIST_DIR}/bin/sqlite3d.dll
                IMPORTED_IMPLIB_DEBUG
                    ${CMAKE_CURRENT_LIST_DIR}/bin/sqlite3d.lib
    )
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        set_target_properties(
            SQLite::SQLite3
            PROPERTIES
                IMPORTED_LOCATION
                    ${CMAKE_CURRENT_LIST_DIR}/bin/libsqlite3.so
                IMPORTED_LOCATION_DEBUG
                    ${CMAKE_CURRENT_LIST_DIR}/bin/libsqlite3d.so
    )
    endif()
    foreach(COMPONENT_NAME ${COMPONENT_NAMES})
        install(
            FILES
                $<TARGET_FILE:SQLite::SQLite3>
            DESTINATION
                .
            COMPONENT
                ${COMPONENT_NAME}
            EXCLUDE_FROM_ALL
        )
    endforeach()
endif()

if(NOT TARGET sqlite3)
    add_executable(
        sqlite3
        IMPORTED
        GLOBAL
    )

    if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        set_target_properties(
            sqlite3
            PROPERTIES
                IMPORTED_LOCATION
                    ${CMAKE_CURRENT_LIST_DIR}/bin/sqlite3.exe
        )
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        set_target_properties(
            sqlite3
            PROPERTIES
                IMPORTED_LOCATION
                    ${CMAKE_CURRENT_LIST_DIR}/bin/sqlite3
        )
    endif()

    foreach(COMPONENT_NAME ${COMPONENT_NAMES})
        install(
            FILES
                $<TARGET_FILE:sqlite3>
            DESTINATION
                .
            COMPONENT
                ${COMPONENT_NAME}
            EXCLUDE_FROM_ALL
        )
    endforeach()
endif()

