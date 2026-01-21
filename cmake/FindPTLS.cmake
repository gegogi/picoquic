# - Try to find Picotls

if (PICOQUIC_FETCH_PTLS)
    set(PTLS_CORE_LIBRARY picotls-core)
    set(PTLS_MINICRYPTO_LIBRARY picotls-minicrypto)

    if(WITH_MBEDTLS)
        find_package_handle_standard_args(PTLS REQUIRED_VARS
            PTLS_CORE_LIBRARY
            PTLS_MINICRYPTO_LIBRARY
            PTLS_INCLUDE_DIR)

        if(PTLS_FOUND)
            set(PTLS_LIBRARIES ${PTLS_CORE_LIBRARY} ${PTLS_MINICRYPTO_LIBRARY})
            set(PTLS_INCLUDE_DIRS ${PTLS_INCLUDE_DIR})
            set(PTLS_WITH_FUSION_DEFAULT OFF)
        endif()
    else()
        set(PTLS_OPENSSL_LIBRARY picotls-openssl)
        if(WITH_FUSION)
            set(PTLS_FUSION_LIBRARY picotls-fusion)
            set(PTLS_WITH_FUSION_DEFAULT ON)
            set(PTLS_LIBRARIES ${PTLS_CORE_LIBRARY} ${PTLS_OPENSSL_LIBRARY} ${PTLS_FUSION_LIBRARY} ${PTLS_MINICRYPTO_LIBRARY})
        else()
            set(PTLS_WITH_FUSION_DEFAULT OFF)
            set(PTLS_LIBRARIES ${PTLS_CORE_LIBRARY} ${PTLS_OPENSSL_LIBRARY}  ${PTLS_MINICRYPTO_LIBRARY})
            unset(PTLS_FUSION_LIBRARY)
        endif()
    endif()
    set(PTLS_INCLUDE_DIRS ${picotls_SOURCE_DIR}/include)
else(PICOQUIC_FETCH_PTLS)
    find_path(PTLS_INCLUDE_DIR
        NAMES picotls/openssl.h
        HINTS ${PTLS_PREFIX}/include/picotls
            ${CMAKE_SOURCE_DIR}/../picotls/include
            ${CMAKE_BINARY_DIR}/../picotls/include
            ../picotls/include/ )

    set(PTLS_HINTS ${PTLS_PREFIX}/lib ${CMAKE_BINARY_DIR}/../picotls/build ../picotls/build ../picotls)

    find_library(PTLS_CORE_LIBRARY picotls-core HINTS ${PTLS_HINTS})
    find_library(PTLS_MINICRYPTO_LIBRARY picotls-minicrypto HINTS ${PTLS_HINTS})

    if(WITH_MBEDTLS)
        find_package_handle_standard_args(PTLS REQUIRED_VARS
            PTLS_CORE_LIBRARY
            PTLS_MINICRYPTO_LIBRARY
            PTLS_INCLUDE_DIR)

        if(PTLS_FOUND)
            set(PTLS_LIBRARIES ${PTLS_CORE_LIBRARY} ${PTLS_MINICRYPTO_LIBRARY})
            set(PTLS_INCLUDE_DIRS ${PTLS_INCLUDE_DIR})
            set(PTLS_WITH_FUSION_DEFAULT OFF)
        endif()
    else()
        find_library(PTLS_OPENSSL_LIBRARY picotls-openssl HINTS ${PTLS_HINTS})
        find_library(PTLS_FUSION_LIBRARY picotls-fusion HINTS ${PTLS_HINTS})

        # 1. 필수 체크 리스트 초기화
        set(PTLS_CHECK_VARS PTLS_CORE_LIBRARY PTLS_MINICRYPTO_LIBRARY PTLS_INCLUDE_DIR)

        # 2. OpenSSL이 켜져 있을 때만 체크 리스트에 추가
        if(WITH_OPENSSL)
            find_library(PTLS_OPENSSL_LIBRARY picotls-openssl HINTS ${PTLS_HINTS})
            list(APPEND PTLS_CHECK_VARS PTLS_OPENSSL_LIBRARY)
        endif()

        # 3. Fusion 라이브러리 검색 (OpenSSL 여부와 상관없이 수행)
        find_library(PTLS_FUSION_LIBRARY picotls-fusion HINTS ${PTLS_HINTS})
        if(PTLS_FUSION_LIBRARY)
            list(APPEND PTLS_CHECK_VARS PTLS_FUSION_LIBRARY)
            set(PTLS_WITH_FUSION_DEFAULT ON)
        else()
            set(PTLS_WITH_FUSION_DEFAULT OFF)
        endif()

        # 4. 최종 통합 체크 호출
        include(FindPackageHandleStandardArgs)
        find_package_handle_standard_args(PTLS REQUIRED_VARS ${PTLS_CHECK_VARS})

        # 5. 결과 변수 설정
        if(PTLS_FOUND)
            set(PTLS_LIBRARIES ${PTLS_CORE_LIBRARY} ${PTLS_MINICRYPTO_LIBRARY})
            if(WITH_OPENSSL)
                list(APPEND PTLS_LIBRARIES ${PTLS_OPENSSL_LIBRARY})
            endif()
            if(PTLS_FUSION_LIBRARY)
                list(APPEND PTLS_LIBRARIES ${PTLS_FUSION_LIBRARY})
            endif()
            set(PTLS_INCLUDE_DIRS ${PTLS_INCLUDE_DIR})
        endif()
    endif()
endif(PICOQUIC_FETCH_PTLS)

mark_as_advanced(PTLS_LIBRARIES PTLS_INCLUDE_DIRS)
