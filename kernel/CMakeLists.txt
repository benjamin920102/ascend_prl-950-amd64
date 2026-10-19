cmake_minimum_required(VERSION 3.16)
set(CMAKE_ASC_ARCHITECTURES "dav-3510" CACHE STRING "NPU architecture")
find_package(ASC REQUIRED)
project(pearl_hlc2 LANGUAGES ASC CXX)
# Tuned config: NINNER=1 NFOLD=32 BUFS=4 VEC2X=2 MBATCH=1
set(NINNER "1"  CACHE STRING "inner matmuls per fold-step")
set(NFOLD  "32" CACHE STRING "fold-steps")
set(BUFS "4" CACHE STRING "slot ping-pong depth")
set(BACKOFF "2000" CACHE STRING "spin backoff iters")
set(VEC2X "2" CACHE STRING "vec consumers per cube producer")
set(MBATCH "1" CACHE STRING "bands per cube IterateAll")
set(GRID_SIZE "20" CACHE STRING "active cube producers; must fit the device")
option(PRL_NATIVE_XOR "Use 950 native register XOR through BitwiseXor" ON)
math(EXPR REMAINDER "${BUFS} % ${VEC2X}")
if(NOT REMAINDER EQUAL 0)
  message(FATAL_ERROR "BUFS must be a multiple of VEC2X")
endif()
if(NOT CMAKE_ASC_ARCHITECTURES STREQUAL "dav-3510")
  message(FATAL_ERROR "This port targets Ascend 950 dav-3510")
endif()
add_library(pearl_hlc2 SHARED pearl_hlc2_cube.asc pearl_hlc2_vec.asc)
set_target_properties(pearl_hlc2 PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_link_libraries(pearl_hlc2 PRIVATE tiling_api register platform m dl pthread)
target_compile_definitions(pearl_hlc2 PRIVATE GRID_SIZE=${GRID_SIZE} PRL_NATIVE_XOR=$<BOOL:${PRL_NATIVE_XOR}>)
target_compile_options(pearl_hlc2 PRIVATE
    $<$<COMPILE_LANGUAGE:ASC>:--npu-arch=${CMAKE_ASC_ARCHITECTURES}>
    $<$<COMPILE_LANGUAGE:ASC>:-DNINNER=${NINNER}>
    $<$<COMPILE_LANGUAGE:ASC>:-DNFOLD=${NFOLD}>
    $<$<COMPILE_LANGUAGE:ASC>:-DBUFS=${BUFS}>
    $<$<COMPILE_LANGUAGE:ASC>:-DBACKOFF=${BACKOFF}>
    $<$<COMPILE_LANGUAGE:ASC>:-DVEC2X=${VEC2X}>
    $<$<COMPILE_LANGUAGE:ASC>:-DMBATCH=${MBATCH}>
)
