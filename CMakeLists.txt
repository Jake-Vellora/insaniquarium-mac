cmake_minimum_required(VERSION 3.16...4.0)

project(insaniquarium LANGUAGES C CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
if(CMAKE_GENERATOR MATCHES "Ninja")
	set(CMAKE_CXX_SCAN_FOR_MODULES OFF)
endif()

set(PVZ_DIR ${CMAKE_CURRENT_SOURCE_DIR}/PvZ-Portable)
set(SAF ${PVZ_DIR}/src/SexyAppFramework)
set(WINFISH_DIR ${CMAKE_CURRENT_SOURCE_DIR}/WinFish/source/WinFish)

# Human-facing port version (shown in the Options menu, and used by release.sh as
# the release tag the in-app updater tracks). Single source of truth: PORT_VERSION.
file(READ ${CMAKE_CURRENT_SOURCE_DIR}/PORT_VERSION WINFISH_PORT_VERSION)
string(STRIP "${WINFISH_PORT_VERSION}" WINFISH_PORT_VERSION)

# Regenerate the flat include dir (WinFish includes <SexyAppFramework/Foo.h> flat-style)
if(NOT EXISTS ${PVZ_DIR}/src/SexyAppFrameworkFlat/SexyAppFramework/SexyAppBase.h)
	execute_process(
		COMMAND bash ${PVZ_DIR}/scripts/create_flat_directory.sh
		WORKING_DIRECTORY ${PVZ_DIR}/scripts
		COMMAND_ERROR_IS_FATAL ANY
	)
endif()

# ---------------- Dependencies ----------------
find_package(Threads REQUIRED)
find_package(ZLIB REQUIRED)
find_package(JPEG REQUIRED)
find_package(PNG REQUIRED)
find_package(SDL2 REQUIRED)

find_library(OGG_LIBRARY NAMES ogg libogg REQUIRED)
find_library(VORBIS_LIBRARY NAMES vorbis libvorbis REQUIRED)
find_library(VORBISFILE_LIBRARY NAMES vorbisfile libvorbisfile REQUIRED)
find_library(OPENMPT_LIBRARY NAMES openmpt libopenmpt REQUIRED)
find_library(MPG123_LIBRARY NAMES mpg123 libmpg123 REQUIRED)

# Vendored SDL-Mixer-X (same option set PvZ-Portable uses)
set(SDL_MIXER_X_STATIC ON CACHE BOOL "Build static library of SDL Mixer X")
set(SDL_MIXER_X_SHARED OFF CACHE BOOL "Build shared library of SDL Mixer X")
set(USE_MIDI OFF CACHE BOOL "SDL Mixer X midi")
set(USE_MODPLUG OFF CACHE BOOL "SDL Mixer X modplug")
set(USE_XMP OFF CACHE BOOL "SDL Mixer X xmp")
set(USE_OPUS OFF CACHE BOOL "SDL Mixer X opus")
set(USE_DRFLAC OFF CACHE BOOL "SDL Mixer X flac")
set(USE_PXTONE OFF CACHE BOOL "SDL Mixer X pxtone")
add_subdirectory(${SAF}/sound/SDL-Mixer-X)

# ---------------- Sources ----------------
file(GLOB FRAMEWORK_SOURCES
	${SAF}/*.cpp
	${SAF}/graphics/*.cpp
	${SAF}/imagelib/*.cpp
	${SAF}/misc/*.cpp
	${SAF}/paklib/*.cpp
	${SAF}/sound/*.cpp
	${SAF}/widget/*.cpp
	${SAF}/fcaseopen/*.c
	${SAF}/ogg/*.c
)
list(APPEND FRAMEWORK_SOURCES
	${SAF}/platform/default/Window.cpp
	${SAF}/platform/default/Input.cpp
)

file(GLOB GAME_SOURCES ${WINFISH_DIR}/*.cpp)

# Objective-C++ sources are NOT caught by the *.cpp glob; list them explicitly.
# The in-app update check (NSURLSession) lives here. ARC is set directory-scoped
# so it applies to both the game and the saver targets that compile this file.
enable_language(OBJCXX)
set(GAME_OBJCXX_SOURCES ${WINFISH_DIR}/UpdateCheck.mm)
set_source_files_properties(${GAME_OBJCXX_SOURCES} PROPERTIES COMPILE_FLAGS "-fobjc-arc")

set(COMMON_INCLUDES
	${SAF}/platform/default
	${PVZ_DIR}/src/SexyAppFrameworkFlat
	${PVZ_DIR}/src
	${SAF}
	${SAF}/sound/SDL-Mixer-X/include
	${SDL2_INCLUDE_DIRS}
)

# Flags for 2004-era MSVC-targeted (and decompiled) code
set(COMMON_C_FLAGS
	-fsigned-char
	-fno-strict-aliasing
	-Wall
	-Wreturn-type
	-Wno-unused-variable
	-Wno-unused-but-set-variable
	-Wno-parentheses
	-Wno-switch
	-Wno-deprecated-declarations
	-Wno-invalid-source-encoding
	-Wno-writable-strings
	-Wno-overloaded-virtual
	-Wno-reorder-ctor
	-Wno-delete-non-abstract-non-virtual-dtor
)

# ---------------- Framework (M0 gate: this compiles) ----------------
add_library(sexyapp OBJECT ${FRAMEWORK_SOURCES})
target_compile_definitions(sexyapp PRIVATE IMG_DOWNSCALE=1)
target_include_directories(sexyapp PRIVATE ${COMMON_INCLUDES})
target_compile_features(sexyapp PRIVATE cxx_std_20)
set_target_properties(sexyapp PROPERTIES CXX_EXTENSIONS OFF)
target_compile_options(sexyapp PRIVATE ${COMMON_C_FLAGS})
target_link_libraries(sexyapp PRIVATE
	SDL2_mixer_ext_Static PNG::PNG JPEG::JPEG ZLIB::ZLIB SDL2::SDL2 Threads::Threads
)

set(COMMON_LIBS
	SDL2_mixer_ext_Static
	${OPENMPT_LIBRARY}
	${MPG123_LIBRARY}
	${VORBISFILE_LIBRARY}
	${VORBIS_LIBRARY}
	${OGG_LIBRARY}
	PNG::PNG
	JPEG::JPEG
	ZLIB::ZLIB
	SDL2::SDL2main
	SDL2::SDL2
	Threads::Threads
)

# ---------------- Game ----------------
add_executable(insaniquarium ${GAME_SOURCES} ${GAME_OBJCXX_SOURCES} $<TARGET_OBJECTS:sexyapp>)
target_compile_definitions(insaniquarium PRIVATE IMG_DOWNSCALE=1 "WINFISH_PORT_VERSION=\"${WINFISH_PORT_VERSION}\"")
target_include_directories(insaniquarium PRIVATE ${COMMON_INCLUDES} ${WINFISH_DIR})
target_compile_features(insaniquarium PRIVATE cxx_std_20)
set_target_properties(insaniquarium PROPERTIES CXX_EXTENSIONS OFF)
target_compile_options(insaniquarium PRIVATE ${COMMON_C_FLAGS})
target_link_libraries(insaniquarium PRIVATE ${COMMON_LIBS} "-framework Foundation")

# ---------------- Asset staging (Steam copy is read-only source) ----------------
set(INSANIQUARIUM_ASSETS_DIR "/Users/jake/games/insaniquarium" CACHE PATH
	"Path to the owned Insaniquarium Deluxe install (read-only asset source)")
if(NOT EXISTS ${INSANIQUARIUM_ASSETS_DIR}/properties/resources.xml)
	message(FATAL_ERROR "Insaniquarium assets not found at ${INSANIQUARIUM_ASSETS_DIR}")
endif()

set(ASSET_DIRS images sounds music fishsongs data properties)
set(STAGED_ASSETS ${CMAKE_BINARY_DIR}/assets)
add_custom_command(OUTPUT ${STAGED_ASSETS}/.staged
	COMMENT "Staging game assets from ${INSANIQUARIUM_ASSETS_DIR}"
	COMMAND ${CMAKE_COMMAND} -E make_directory ${STAGED_ASSETS})
foreach(d ${ASSET_DIRS})
	add_custom_command(OUTPUT ${STAGED_ASSETS}/.staged APPEND
		COMMAND ${CMAKE_COMMAND} -E copy_directory
			${INSANIQUARIUM_ASSETS_DIR}/${d} ${STAGED_ASSETS}/${d})
endforeach()
add_custom_command(OUTPUT ${STAGED_ASSETS}/.staged APPEND
	COMMAND ${CMAKE_COMMAND} -E touch ${STAGED_ASSETS}/.staged)
add_custom_target(stage_assets DEPENDS ${STAGED_ASSETS}/.staged)
add_dependencies(insaniquarium stage_assets)

# ---------------- macOS screensaver (.saver) ----------------
enable_language(OBJCXX)
set(SAVER_GAME_SOURCES ${GAME_SOURCES})
list(REMOVE_ITEM SAVER_GAME_SOURCES ${WINFISH_DIR}/Window.cpp)

add_library(insaniquarium-saver MODULE
	${SAVER_GAME_SOURCES}
	${GAME_OBJCXX_SOURCES}
	${CMAKE_CURRENT_SOURCE_DIR}/saver/InsaniquariumSaverView.mm
	$<TARGET_OBJECTS:sexyapp>
)
set_target_properties(insaniquarium-saver PROPERTIES
	BUNDLE TRUE
	BUNDLE_EXTENSION "saver"
	OUTPUT_NAME "Insaniquarium"
	MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/saver/Info.plist
	CXX_EXTENSIONS OFF
)
target_compile_definitions(insaniquarium-saver PRIVATE IMG_DOWNSCALE=1 "WINFISH_PORT_VERSION=\"${WINFISH_PORT_VERSION}\"")
target_include_directories(insaniquarium-saver PRIVATE ${COMMON_INCLUDES} ${WINFISH_DIR})
target_compile_features(insaniquarium-saver PRIVATE cxx_std_20)
target_compile_options(insaniquarium-saver PRIVATE ${COMMON_C_FLAGS})
set_source_files_properties(${CMAKE_CURRENT_SOURCE_DIR}/saver/InsaniquariumSaverView.mm
	PROPERTIES COMPILE_FLAGS "-fobjc-arc")
target_link_libraries(insaniquarium-saver PRIVATE
	${COMMON_LIBS}
	"-framework ScreenSaver"
	"-framework Cocoa"
	"-framework OpenGL"
	"-framework QuartzCore"
)

add_executable(saverhost ${CMAKE_CURRENT_SOURCE_DIR}/saver/SaverHost.mm)
set_source_files_properties(${CMAKE_CURRENT_SOURCE_DIR}/saver/SaverHost.mm
	PROPERTIES COMPILE_FLAGS "-fobjc-arc")
target_link_libraries(saverhost PRIVATE
	"-framework ScreenSaver"
	"-framework Cocoa"
)

# ---------------- M1 rendering spike ----------------
if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/spike/main.cpp)
	add_executable(spike ${CMAKE_CURRENT_SOURCE_DIR}/spike/main.cpp $<TARGET_OBJECTS:sexyapp>)
	target_include_directories(spike PRIVATE ${COMMON_INCLUDES})
	target_compile_features(spike PRIVATE cxx_std_20)
	target_compile_options(spike PRIVATE ${COMMON_C_FLAGS})
	target_link_libraries(spike PRIVATE ${COMMON_LIBS})
endif()
