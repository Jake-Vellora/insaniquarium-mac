if(NOT EMSCRIPTEN)
	message(FATAL_ERROR "Project-local FindSDL2.cmake is intended for Emscripten only")
endif()

if(NOT TARGET SDL2::SDL2)
	add_library(SDL2::SDL2 INTERFACE IMPORTED)
	set_target_properties(SDL2::SDL2 PROPERTIES
		INTERFACE_COMPILE_OPTIONS "SHELL:-sUSE_SDL=2"
		INTERFACE_LINK_OPTIONS "SHELL:-sUSE_SDL=2")
endif()

set(SDL2_FOUND TRUE)
set(SDL2_INCLUDE_DIRS "")
set(SDL2_LIBRARIES SDL2::SDL2)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(SDL2 DEFAULT_MSG SDL2_LIBRARIES)