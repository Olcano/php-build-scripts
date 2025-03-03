@echo off

REM For future users: This file MUST have CRLF line endings. If it doesn't, lots of inexplicable undesirable strange behaviour will result.
REM Also: Don't modify this version with sed, or it will screw up your line endings.
set PHP_MAJOR_VER=8.2
set PHP_VER=%PHP_MAJOR_VER%.7
set PHP_GIT_REV=php-%PHP_VER%
set PHP_DISPLAY_VER=%PHP_VER%
set PHP_SDK_VER=2.2.0
set PATH=C:\Program Files\7-Zip;C:\Program Files (x86)\GnuWin32\bin;%PATH%
set VC_VER=vs16
set ARCH=x64
set VS_VER=
set VS_YEAR=
set CMAKE_TARGET=
if "%PHP_DEBUG_BUILD%"=="" (
	set PHP_DEBUG_BUILD=0
)
set MSBUILD_CONFIGURATION=RelWithDebInfo
set PHP_JIT_ENABLE_ARG=off

set LIBYAML_VER=0.2.5
set PTHREAD_W32_VER=3.0.0
set LEVELDB_MCPE_VER=1c7564468b41610da4f498430e795ca4de0931ff
set LIBDEFLATE_VER=495fee110ebb48a5eb63b75fd67e42b2955871e2
set LIBRDKAFKA_VER=2.1.1
set LIBZSTD_VER=1.5.5
set LIBGRPC_VER=1.56.0

set PHP_PTHREADS_VER=4.2.1
set PHP_PMMPTHREAD_VER=6.0.4
set PHP_YAML_VER=2.2.3
set PHP_CHUNKUTILS2_VER=0.3.5
set PHP_IGBINARY_VER=3.2.14
set PHP_LEVELDB_VER=317fdcd8415e1566fc2835ce2bdb8e19b890f9f3
set PHP_CRYPTO_VER=0.3.2
set PHP_RECURSIONGUARD_VER=0.1.0
set PHP_MORTON_VER=0.1.2
set PHP_LIBDEFLATE_VER=0.2.1
set PHP_XXHASH_VER=0.2.0
set PHP_XDEBUG_VER=3.2.1
set PHP_ARRAYDEBUG_VER=0.1.0
set PHP_VANILLAGENERATOR_VER=56fc48ea1367e1d08b228dfa580b513fbec8ca31
set PHP_LIBKAFKA_VER=6.0.3
set PHP_ZSTD_VER=0.12.3

set script_path=%~dp0
set log_file=%script_path%compile.log
echo.>"%log_file%"

set outpath="%cd%"

where git >nul 2>nul || (call :pm-echo-error "git is required" & exit 1)
where cmake >nul 2>nul || (call :pm-echo-error "cmake is required" & exit 1)
where 7z >nul 2>nul || (call :pm-echo-error "7z is required" & exit 1)
where wget >nul 2>nul || (call :pm-echo-error "wget is required" & exit 1)

REM to ensure we use the correct version of wget - the SDK provides an outdated one that has outdated SSL certs
set ORIG_PATH=%PATH%

call :pm-echo "PHP Windows compiler"
call :pm-echo "Setting up environment..."

if "%PHP_DEBUG_BUILD%"=="0" (
	set OUT_PATH_REL=Release
	set PHP_HAVE_DEBUG=enable-debug-pack
	call :pm-echo "Building release binaries with debug symbols"
) else (
	set OUT_PATH_REL=Debug
	set PHP_HAVE_DEBUG=enable-debug
	REM I don't like this, but YAML will crash if it's not built with the same target as PHP
	set MSBUILD_CONFIGURATION=Debug
	call :pm-echo "Building debug binaries"
)

if "%PHP_JIT_SUPPORT%"=="1" (
    set PHP_JIT_ENABLE_ARG=on
    call :pm-echo "Compiling JIT support in OPcache (unstable)"
)

if "%PM_VERSION_MAJOR%"=="" (
    call :pm-echo-error "Please specify PocketMine-MP major version by setting the PM_VERSION_MAJOR environment variable"
    exit 1
)

call :pm-echo "Compiling with configuration for PocketMine-MP %PM_VERSION_MAJOR%"

if "%SOURCES_PATH%"=="" (
	if "%PHP_DEBUG_BUILD%"=="0" (
		set SOURCES_PATH=C:\pocketmine-php-%PHP_DISPLAY_VER%-release
	) else (
		set SOURCES_PATH=C:\pocketmine-php-%PHP_DISPLAY_VER%-debug
	)
)
call :pm-echo "Using path %SOURCES_PATH% for build sources"

call :check-vs-exists 2019 16 || call :pm-fatal-error "Please install Visual Studio 2019"

REM export an env var to override this if you're using something other than the community edition
if "%VS_EDITION%"=="" (
	set VS_EDITION=Community
)
call "C:\Program Files (x86)\Microsoft Visual Studio\%VS_YEAR%\%VS_EDITION%\VC\Auxiliary\Build\vcvarsall.bat" %ARCH% >>"%log_file%" 2>&1 || call :pm-fatal-error "Error initializing Visual Studio environment"
:batchfiles-are-stupid
move "%log_file%" "%log_file%" >nul 2>nul || goto :batchfiles-are-stupid

cd /D "%outpath%"

if exist bin (
	call :pm-echo "Deleting old binary folder..."
	rmdir /s /q bin >>"%log_file%" 2>&1 || call :pm-fatal-error "Failed to delete old binary folder"
)

if exist "%SOURCES_PATH%" (
	call :pm-echo "Deleting old workspace..."
	rmdir /s /q "%SOURCES_PATH%" >>"%log_file%" 2>&1 || call :pm-fatal-error "Failed to delete old workspace"
)

call :pm-echo "Getting SDK..."
git clone https://github.com/OSTC/php-sdk-binary-tools.git -b php-sdk-%PHP_SDK_VER% --depth=1 -q "%SOURCES_PATH%" >>"%log_file%" 2>&1 || call :pm-fatal-error "Failed to download SDK"

cd /D "%SOURCES_PATH%"

call bin\phpsdk_setvars.bat >>"%log_file%" 2>&1

call :pm-echo "Downloading PHP source version %PHP_VER%..."
call :get-zip https://github.com/php/php-src/archive/%PHP_GIT_REV%.zip || call :pm-fatal-error "Failed to download PHP source"
move php-src-%PHP_GIT_REV% php-src >>"%log_file%" 2>&1 || call :pm-fatal-error "Failed to move PHP source to target directory"

set DEPS_DIR_NAME=deps
set DEPS_DIR="%SOURCES_PATH%\%DEPS_DIR_NAME%"

call :pm-echo "Downloading PHP dependencies into %DEPS_DIR%..."
call bin\phpsdk_deps.bat -u -t %VC_VER% -b %PHP_MAJOR_VER% -a %ARCH% -f -d %DEPS_DIR_NAME% >>"%log_file%" 2>&1 || exit 1


call :pm-echo "Getting additional dependencies..."
cd /D "%DEPS_DIR%"

call :pm-echo "Downloading grpc/grpc version %LIBGRPC_VER%..."
git clone -b v%LIBGRPC_VER% --depth=1 https://github.com/grpc/grpc >>"%log_file%" 2>&1 || exit 1
cd /D grpc

call :pm-echo "Updating submodules..."
git submodule update --depth=1 --init >>"%log_file%" 2>&1 || exit 1

call :pm-echo "Generating build configuration..."
cd cmake
md build
cd build
cmake -GNinja^
 -DCMAKE_PREFIX_PATH="%DEPS_DIR%"^
 -DCMAKE_INSTALL_PREFIX="%DEPS_DIR%"^
 -DCMAKE_BUILD_TYPE="%MSBUILD_CONFIGURATION%"^
 -DZLIB_LIBRARY="%DEPS_DIR%\lib\zlib_a.lib"^
 -DgRPC_BUILD_CSHARP_EXT=OFF^
 -DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF^
 -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF^
 -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF^
 -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF^
 -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF^
 -DgRPC_SSL_PROVIDER="package"^
 -DgRPC_ZLIB_PROVIDER="package"^
 ..\.. >>"%log_file%" 2>&1 || exit 1

call :pm-echo "Compiling..."
cmake --build . >> "%log_file%" 2>&1 || exit 1
call :pm-echo "Installing files..."
cmake -P cmake_install.cmake >> "%log_file%" 2>&1 || exit 1
cd /D "%DEPS_DIR%"

call :pm-echo "Moving php-gRPC extension source..."
move grpc\src\php\ext\grpc ..\php-src\ext\grpc >> "%log_file%" 2>&1 || exit 1
move grpc\third_party\protobuf\php\ext\google\protobuf ..\php-src\ext\protobuf >> "%log_file%" 2>&1 || exit 1
move grpc\third_party\protobuf\third_party ..\php-src\ext\protobuf\third_party >> "%log_file%" 2>&1 || exit 1
cd ..\php-src\ext\protobuf

call :pm-echo "Generating files..."
echo|(set /p="ARG_ENABLE("protobuf", "Enable Protobuf extension", "yes");" & echo.) >> config.w32
echo|(set /p="" & echo.) >> config.w32
echo|(set /p="if (PHP_PROTOBUF != "no") {" & echo.) >> config.w32
echo|(set /p="  EXTENSION("protobuf", "arena.c array.c convert.c def.c map.c message.c names.c php-upb.c protobuf.c", PHP_PROTOBUF_SHARED, "");" & echo.) >> config.w32
echo|(set /p="" & echo.) >> config.w32
echo|(set /p="  ADD_SOURCES(configure_module_dirname + "/third_party/utf8_range", "naive.c range2-neon.c range2-sse.c", "protobuf");" & echo.) >> config.w32
echo|(set /p="" & echo.) >> config.w32
echo|(set /p="  AC_DEFINE('HAVE_PROTOBUF', 1, '');" & echo.) >> config.w32
echo|(set /p="}" & echo.) >> config.w32

cd ..\grpc

call :pm-echo "Generating config.w32..."
echo|(set /p="ARG_ENABLE("grpc", "Enable grpc support", "yes");" & echo.) >> config.w32
echo|(set /p="if (PHP_GRPC != "no") {" & echo.) >> config.w32
echo|(set /p="if (SETUP_OPENSSL("grpc", PHP_GRPC) &&" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("zlib_a.lib;zlib.lib", "grpc", PHP_GRPC) &&" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("grpc.lib", "grpc", PHP_GRPC) &&" & echo.) >> config.w32
echo|(set /p="CHECK_HEADER_ADD_INCLUDE("grpc/grpc.h", "CFLAGS_GRPC")) {" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("cares.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("re2.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("address_sorting.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("gpr.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("grpc_authorization_provider.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("grpc_plugin_support.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("upb.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("libprotobuf-lite.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("libprotobuf.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("libprotoc.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_log_severity.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_raw_logging_internal.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_spinlock_wait.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_malloc_internal.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_base.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_throw_delegate.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_scoped_set_env.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_strerror.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_hashtablez_sampler.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_raw_hash_set.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_crc_cpu_detect.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_crc_internal.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_crc32c.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_crc_cord_state.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_stacktrace.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_symbolize.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_examine_stack.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_failure_signal_handler.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_debugging_internal.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_demangle_internal.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_leak_check.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_flags_program_name.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_flags_config.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_flags_marshalling.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_flags_commandlineflag_internal.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_flags_commandlineflag.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_flags_private_handle_accessor.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_flags_reflection.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_flags_internal.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_flags.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_flags_usage_internal.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_flags_usage.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_flags_parse.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_hash.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_city.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_low_level_hash.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_log_internal_check_op.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_log_internal_conditions.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_log_internal_format.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_log_internal_globals.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_log_internal_proto.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_log_internal_message.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_log_internal_log_sink_set.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_log_internal_nullguard.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_die_if_null.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_log_flags.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_log_globals.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_log_initialize.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_log_entry.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_log_sink.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_int128.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_exponential_biased.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_periodic_sampler.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_random_distributions.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_random_seed_gen_exception.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_random_seed_sequences.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_random_internal_seed_material.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_random_internal_pool_urbg.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_random_internal_platform.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_random_internal_randen.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_random_internal_randen_slow.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_random_internal_randen_hwaes.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_random_internal_randen_hwaes_impl.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_random_internal_distribution_test_util.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_status.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_statusor.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_strings.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_strings_internal.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_str_format_internal.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_cord_internal.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_cordz_functions.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_cordz_handle.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_cordz_info.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_cordz_sample_token.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_cord.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_graphcycles_internal.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_synchronization.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_time.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_civil_time.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_time_zone.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_bad_any_cast_impl.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_bad_optional_access.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="CHECK_LIB("absl_bad_variant_access.lib", "grpc", PHP_GRPC);" & echo.) >> config.w32
echo|(set /p="EXTENSION("grpc", "byte_buffer.c call.c call_credentials.c channel.c channel_credentials.c completion_queue.c timeval.c server.c server_credentials.c php_grpc.c", PHP_GRPC_SHARED, "");" & echo.) >> config.w32
echo|(set /p="AC_DEFINE('HAVE_GRPC', 1, '');" & echo.) >> config.w32
echo|(set /p="} else {" & echo.) >> config.w32
echo|(set /p="WARNING("php-grpc not enabled; libraries and headers not found");" & echo.) >> config.w32
echo|(set /p="}" & echo.) >> config.w32
echo|(set /p="}" & echo.) >> config.w32

cd ..\protobuf

cd /D "%DEPS_DIR%"

call :pm-echo "Downloading zstd version %LIBZSTD_VER%..."
call :get-zip "https://github.com/facebook/zstd/archive/v%LIBZSTD_VER%.zip" || exit 1
move zstd-%LIBZSTD_VER% zstd >> "%log_file%" 2>&1
cd zstd/build/cmake
call :pm-echo "Generating build configuration..."
cmake -G "%CMAKE_TARGET%" -A "%ARCH%"^
 -DCMAKE_PREFIX_PATH="%DEPS_DIR%"^
 -DCMAKE_INSTALL_PREFIX="%DEPS_DIR%"^
 -DBUILD_SHARED_LIBS=ON^
 . >>"%log_file%" 2>&1 || exit 1
call :pm-echo "Compiling..."
msbuild ALL_BUILD.vcxproj /p:Configuration=%MSBUILD_CONFIGURATION% /m >>"%log_file%" 2>&1 || exit 1
call :pm-echo "Installing files..."
msbuild INSTALL.vcxproj /p:Configuration=%MSBUILD_CONFIGURATION% /m >>"%log_file%" 2>&1 || exit 1
cd /D "%DEPS_DIR%"

call :pm-echo "Downloading librdkafka version %LIBRDKAFKA_VER%..."
call :get-zip https://github.com/confluentinc/librdkafka/archive/v%LIBRDKAFKA_VER%.zip || exit 1
move librdkafka-* librdkafka >>"%log_file%" 2>&1
cd /D librdkafka

call :pm-echo "Generating build configuration..."

cmake -G "%CMAKE_TARGET%" -A "%ARCH%"^
 -DCMAKE_PREFIX_PATH="%DEPS_DIR%"^
 -DCMAKE_INSTALL_PREFIX="%DEPS_DIR%"^
 -DBUILD_SHARED_LIBS=ON^
 . >>"%log_file%" 2>&1 || exit 1

call :pm-echo "Compiling..."
msbuild ALL_BUILD.vcxproj /p:Configuration=%MSBUILD_CONFIGURATION% >>"%log_file%" 2>&1 || exit 1
call :pm-echo "Installing files..."
msbuild INSTALL.vcxproj /p:Configuration=%MSBUILD_CONFIGURATION% /m >>"%log_file%" 2>&1 || exit 1

cd /D "%DEPS_DIR%"

REM for no reason, php-rdkafka check for librdkafka and not rdkafka
REM move them to the appropriate location for php-rdkafka compatibility.
call :pm-echo "Moving libraries files for php-rdkafka compatibility..."
move "lib\rdkafka.lib" "lib\librdkafka.lib" >>"%log_file%" 2>&1
move "lib\rdkafka++.lib" "lib\librdkafka++.lib" >>"%log_file%" 2>&1

call :pm-echo "Downloading LibYAML version %LIBYAML_VER%..."
call :get-zip https://github.com/yaml/libyaml/archive/%LIBYAML_VER%.zip || exit 1
move libyaml-%LIBYAML_VER% libyaml >>"%log_file%" 2>&1
cd /D libyaml
call :pm-echo "Generating build configuration..."
cmake -G "%CMAKE_TARGET%" -A "%ARCH%"^
 -DCMAKE_PREFIX_PATH="%DEPS_DIR%"^
 -DCMAKE_INSTALL_PREFIX="%DEPS_DIR%"^
 -DBUILD_SHARED_LIBS=ON^
 . >>"%log_file%" 2>&1 || exit 1
call :pm-echo "Compiling..."
msbuild ALL_BUILD.vcxproj /p:Configuration=%MSBUILD_CONFIGURATION% /m >>"%log_file%" 2>&1 || exit 1
call :pm-echo "Installing files..."
msbuild INSTALL.vcxproj /p:Configuration=%MSBUILD_CONFIGURATION% /m >>"%log_file%" 2>&1 || exit 1
copy %MSBUILD_CONFIGURATION%\yaml.pdb "%DEPS_DIR%\bin\yaml.pdb" >>"%log_file%" 2>&1 || exit 1

cd /D "%DEPS_DIR%"

call :pm-echo "Downloading pthread-w32 version %PTHREAD_W32_VER%..."
mkdir pthread-w32
cd /D pthread-w32
call :get-zip https://github.com/pmmp/DependencyMirror/releases/download/mirror/pthreads4w-code-v%PTHREAD_W32_VER%.zip || exit 1
move pthreads4w-code-* pthreads4w-code >>"%log_file%" 2>&1
cd /D pthreads4w-code

call :pm-echo "Compiling..."
nmake VC >>"%log_file%" 2>&1 || exit 1

call :pm-echo "Copying files..."
copy pthread.h "%DEPS_DIR%\include\pthread.h" >>"%log_file%" 2>&1 || exit 1
copy sched.h "%DEPS_DIR%\include\sched.h" >>"%log_file%" 2>&1 || exit 1
copy semaphore.h "%DEPS_DIR%\include\semaphore.h" >>"%log_file%" 2>&1 || exit 1
copy _ptw32.h "%DEPS_DIR%\include\_ptw32.h" >>"%log_file%" 2>&1 || exit 1
copy pthreadVC3.lib "%DEPS_DIR%\lib\pthreadVC3.lib" >>"%log_file%" 2>&1 || exit 1
copy pthreadVC3.dll "%DEPS_DIR%\bin\pthreadVC3.dll" >>"%log_file%" 2>&1 || exit 1
copy pthreadVC3.pdb "%DEPS_DIR%\bin\pthreadVC3.pdb" >>"%log_file%" 2>&1 || exit 1

cd /D "%DEPS_DIR%"

call :pm-echo "Downloading pmmp/leveldb version %LEVELDB_MCPE_VER%..."
call :get-zip https://github.com/pmmp/leveldb/archive/%LEVELDB_MCPE_VER%.zip || exit 1
move leveldb-%LEVELDB_MCPE_VER% leveldb >>"%log_file%" 2>&1
cd /D leveldb

call :pm-echo "Generating build configuration..."
cmake -G "%CMAKE_TARGET%" -A "%ARCH%"^
 -DCMAKE_PREFIX_PATH="%DEPS_DIR%"^
 -DCMAKE_INSTALL_PREFIX="%DEPS_DIR%"^
 -DBUILD_SHARED_LIBS=ON^
 -DLEVELDB_BUILD_BENCHMARKS=OFF^
 -DLEVELDB_BUILD_TESTS=OFF^
 -DZLIB_LIBRARY="%DEPS_DIR%\lib\zlib_a.lib"^
 . >>"%log_file%" 2>&1 || exit 1
call :pm-echo "Compiling"
msbuild ALL_BUILD.vcxproj /p:Configuration=%MSBUILD_CONFIGURATION% /m >>"%log_file%" 2>&1 || exit 1
call :pm-echo "Installing files..."
msbuild INSTALL.vcxproj /p:Configuration=%MSBUILD_CONFIGURATION% >>"%log_file%" 2>&1 || exit 1
copy %MSBUILD_CONFIGURATION%\leveldb.pdb "%DEPS_DIR%\bin\leveldb.pdb" >>"%log_file%" 2>&1 || exit 1

cd /D "%DEPS_DIR%"

call :pm-echo "Downloading libdeflate version %LIBDEFLATE_VER%..."
call :get-zip https://github.com/ebiggers/libdeflate/archive/%LIBDEFLATE_VER%.zip || exit 1
move libdeflate-%LIBDEFLATE_VER% libdeflate >>"%log_file%" 2>&1
cd /D libdeflate

call :pm-echo "Generating build configuration..."
cmake -G "%CMAKE_TARGET%" -A "%ARCH%"^
 -DCMAKE_PREFIX_PATH="%DEPS_DIR%"^
 -DCMAKE_INSTALL_PREFIX="%DEPS_DIR%"^
 -DLIBDEFLATE_BUILD_GZIP=OFF^
 -DLIBDEFLATE_BUILD_SHARED_LIB=ON^
 -DLIBDEFLATE_BUILD_STATIC_LIB=OFF^
 . >>"%log_file%" 2>&1 || exit 1
call :pm-echo "Compiling"
msbuild ALL_BUILD.vcxproj /p:Configuration=%MSBUILD_CONFIGURATION% /m >>"%log_file%" 2>&1 || exit 1
call :pm-echo "Installing files..."
msbuild INSTALL.vcxproj /p:Configuration=%MSBUILD_CONFIGURATION% >>"%log_file%" 2>&1 || exit 1
copy %MSBUILD_CONFIGURATION%\deflate.pdb "%DEPS_DIR%\bin\deflate.pdb" >>"%log_file%" 2>&1 || exit 1

cd /D "%DEPS_DIR%"

cd /D ..

call :pm-echo "Getting additional PHP extensions..."
cd /D php-src\ext

set THREAD_EXT_FLAGS=""
if "%PM_VERSION_MAJOR%" geq "5" (
    call :get-extension-zip-from-github "pmmpthread" "%PHP_PMMPTHREAD_VER%" "pmmp" "ext-pmmpthread" || exit 1
    set THREAD_EXT_FLAGS="--with-pmmpthread=shared"
) else (
    call :get-extension-zip-from-github "pthreads" "%PHP_PTHREADS_VER%" "pmmp" "ext-pmmpthread" || exit 1
    set THREAD_EXT_FLAGS="--with-pthreads=shared"
)
call :get-extension-zip-from-github "yaml"                  "%PHP_YAML_VER%"                  "php"      "pecl-file_formats-yaml"  || exit 1
call :get-extension-zip-from-github "chunkutils2"           "%PHP_CHUNKUTILS2_VER%"           "pmmp"     "ext-chunkutils2"         || exit 1
call :get-extension-zip-from-github "igbinary"              "%PHP_IGBINARY_VER%"              "igbinary" "igbinary"                || exit 1
call :get-extension-zip-from-github "leveldb"               "%PHP_LEVELDB_VER%"               "pmmp"     "php-leveldb"             || exit 1
call :get-extension-zip-from-github "recursionguard"        "%PHP_RECURSIONGUARD_VER%"        "pmmp"     "ext-recursionguard"      || exit 1
call :get-extension-zip-from-github "morton"                "%PHP_MORTON_VER%"                "pmmp"     "ext-morton"              || exit 1
call :get-extension-zip-from-github "libdeflate"            "%PHP_LIBDEFLATE_VER%"            "pmmp"     "ext-libdeflate"          || exit 1
call :get-extension-zip-from-github "xxhash"                "%PHP_XXHASH_VER%"                "pmmp"     "ext-xxhash"              || exit 1
call :get-extension-zip-from-github "xdebug"                "%PHP_XDEBUG_VER%"                "xdebug"   "xdebug"                  || exit 1
call :get-extension-zip-from-github "arraydebug"            "%PHP_ARRAYDEBUG_VER%"            "pmmp"     "ext-arraydebug"          || exit 1
call :get-extension-zip-from-github "vanillagenerator"      "%PHP_VANILLAGENERATOR_VER%" "NetherGamesMC" "ext-vanillagenerator"    || exit 1
call :get-extension-zip-from-github "rdkafka"               "%PHP_LIBKAFKA_VER%"             "arnaud-lb" "php-rdkafka"             || exit 1
call :get-extension-zip-from-github "zstd"                  "%PHP_ZSTD_VER%"             "kjdev"     "php-ext-zstd"                || exit 1

call :pm-echo " - crypto: downloading %PHP_CRYPTO_VER%..."
git clone https://github.com/bukka/php-crypto.git crypto >>"%log_file%" 2>&1 || exit 1
cd /D crypto
git checkout %PHP_CRYPTO_VER% >>"%log_file%" 2>&1 || exit 1
git submodule update --init --recursive >>"%log_file%" 2>&1 || exit 1
cd /D ..

cd /D ..\..

:skip
cd /D php-src
call :pm-echo "Configuring PHP..."
call buildconf.bat >>"%log_file%" 2>&1

REM https://github.com/php/php-src/pull/6658 - this is needed until 8.0.3 releases because php-sdk gives us dependencies that won't otherwise build
set LDFLAGS="/d2:-AllowCompatibleILVersions"

call configure^
 --with-mp=auto^
 --with-prefix=pocketmine-php-bin^
 --%PHP_HAVE_DEBUG%^
 --disable-all^
 --disable-cgi^
 --enable-cli^
 --enable-zts^
 --enable-pdo^
 --enable-arraydebug=shared^
 --enable-bcmath^
 --enable-calendar^
 --enable-chunkutils2=shared^
 --enable-com-dotnet^
 --enable-ctype^
 --enable-fileinfo=shared^
 --enable-filter^
 --enable-hash^
 --enable-igbinary=shared^
 --enable-json^
 --enable-mbstring^
 --enable-morton^
 --enable-opcache^
 --enable-opcache-jit=%PHP_JIT_ENABLE_ARG%^
 --enable-phar^
 --enable-vanillagenerator=shared^
 --enable-zstd^
 --enable-grpc=shared^
 --enable-protobuf=shared^
 --enable-recursionguard=shared^
 --enable-sockets^
 --enable-tokenizer^
 --enable-xmlreader^
 --enable-xmlwriter^
 --enable-xxhash^
 --enable-zip^
 --enable-zlib^
 --with-bz2=shared^
 --with-crypto=shared^
 --with-curl^
 --with-dom^
 --with-gd=shared^
 --with-gmp^
 --with-iconv^
 --with-leveldb=shared^
 --with-libdeflate=shared^
 --with-libxml^
 --with-mysqli=shared^
 --with-mysqlnd^
 --with-openssl^
 --with-pcre-jit^
 %THREAD_EXT_FLAGS%^
 --with-simplexml^
 --with-sodium^
 --with-sqlite3=shared^
 --with-xdebug=shared^
 --with-xdebug-compression^
 --with-xml^
 --with-yaml^
 --with-rdkafka=shared^
 --with-pdo-mysql^
 --with-pdo-sqlite^
 --without-readline >>"%log_file%" 2>&1 || call :pm-fatal-error "Error configuring PHP"

call :pm-echo "Compiling PHP..."
nmake >>"%log_file%" 2>&1 || call :pm-fatal-error "Error compiling PHP"

call :pm-echo "Assembling artifacts..."
nmake snap >>"%log_file%" 2>&1 || call :pm-fatal-error "Error assembling artifacts"

call :pm-echo "Removing unneeded dependency DLLs..."
REM remove ICU DLLs copied unnecessarily by nmake snap - this needs to be removed if we ever have ext/intl as a dependency
del /q "%SOURCES_PATH%\php-src\%ARCH%\Release_TS\php-%PHP_DISPLAY_VER%\icu*.dll" 2>&1
REM remove enchant dependencies which are unnecessarily copied - this needs to be removed if we ever have ext/enchant as a dependency
del /q "%SOURCES_PATH%\php-src\%ARCH%\Release_TS\php-%PHP_DISPLAY_VER%\glib-*.dll" 2>&1
del /q "%SOURCES_PATH%\php-src\%ARCH%\Release_TS\php-%PHP_DISPLAY_VER%\gmodule-*.dll" 2>&1
rmdir /s /q "%SOURCES_PATH%\php-src\%ARCH%\Release_TS\php-%PHP_DISPLAY_VER%\lib\enchant\" 2>&1

call :pm-echo "Copying artifacts..."
cd /D "%outpath%"
mkdir bin bin\grpc
move "%DEPS_DIR%\grpc\cmake\build\grpc_php_plugin.exe" "bin\grpc\grpc_php_plugin.exe"
move "%DEPS_DIR%\grpc\cmake\build\third_party\protobuf\protoc.exe" "bin\grpc\protoc.exe"
move "%SOURCES_PATH%\php-src\%ARCH%\%OUT_PATH_REL%_TS\php-%PHP_DISPLAY_VER%" bin\php
cd /D bin\php

set php_ini=php.ini
call :pm-echo "Generating php.ini..."
(echo ;Custom PocketMine-MP php.ini file)>"%php_ini%"
(echo memory_limit=1024M)>>"%php_ini%"
(echo display_errors=1)>>"%php_ini%"
(echo display_startup_errors=1)>>"%php_ini%"
(echo error_reporting=-1)>>"%php_ini%"
(echo zend.assertions=-1)>>"%php_ini%"
(echo extension_dir=ext)>>"%php_ini%"
if "%PM_VERSION_MAJOR%" geq "5" (
    (echo extension=php_pmmpthread.dll)>>"%php_ini%"
) else (
    (echo extension=php_pthreads.dll)>>"%php_ini%"
)
(echo extension=php_openssl.dll)>>"%php_ini%"
(echo extension=php_chunkutils2.dll)>>"%php_ini%"
(echo extension=php_igbinary.dll)>>"%php_ini%"
(echo extension=php_leveldb.dll)>>"%php_ini%"
(echo extension=php_crypto.dll)>>"%php_ini%"
(echo extension=php_libdeflate.dll)>>"%php_ini%
(echo igbinary.compact_strings=0)>>"%php_ini%"
(echo zend_extension=php_opcache.dll)>>"%php_ini%"
(echo opcache.enable=1)>>"%php_ini%"
(echo opcache.enable_cli=1)>>"%php_ini%"
(echo opcache.save_comments=1)>>"%php_ini%"
(echo opcache.validate_timestamps=1)>>"%php_ini%"
(echo opcache.revalidate_freq=0)>>"%php_ini%"
(echo opcache.file_update_protection=0)>>"%php_ini%"
(echo opcache.optimization_level=0x7FFEBFFF)>>"%php_ini%"
(echo opcache.cache_id=PHP_BINARY ;prevent sharing SHM between different binaries - they won't work because of ASLR)>>"%php_ini%"
(echo ;Optional extensions, supplied for PM3 use)>>"%php_ini%"
(echo ;Optional extensions, supplied for plugin use)>>"%php_ini%"
(echo extension=php_fileinfo.dll)>>"%php_ini%"
(echo extension=php_gd.dll)>>"%php_ini%"
(echo extension=php_grpc.dll)>>"%php_ini%"
(echo extension=php_protobuf.dll)>>"%php_ini%"
(echo extension=php_vanillagenerator.dll)>>"%php_ini%"
(echo extension=php_rdkafka.dll)>>"%php_ini%"
(echo extension=php_mysqli.dll)>>"%php_ini%"
(echo extension=php_sqlite3.dll)>>"%php_ini%"
(echo ;Optional extensions, supplied for debugging)>>"%php_ini%"
(echo extension=php_recursionguard.dll)>>"%php_ini%"
(echo recursionguard.enabled=0 ;disabled due to minor performance impact, only enable this if you need it for debugging)>>"%php_ini%"
(echo ;extension=php_arraydebug.dll)>>"%php_ini%"
(echo.)>>"%php_ini%"
if "%PHP_JIT_ENABLE_ARG%"=="on" (
    (echo ; ---- ! WARNING ! ----)>>"%php_ini%"
    (echo ; JIT can provide big performance improvements, but as of PHP %PHP_VER% it is still unstable. For this reason, it is disabled by default.)>>"%php_ini%"
    (echo ; Enable it at your own risk. See https://www.php.net/manual/en/opcache.configuration.php#ini.opcache.jit for possible options.)>>"%php_ini%"
    (echo opcache.jit=off)>>"%php_ini%"
    (echo opcache.jit_buffer_size=128M)>>"%php_ini%"
    (echo.)>>"%php_ini%"
)
(echo ;WARNING: When loaded, xdebug 3.2.0 will cause segfaults whenever an uncaught error is thrown, even if xdebug.mode=off. Load it at your own risk.)>>"%php_ini%"
(echo ;zend_extension=php_xdebug.dll)>>"%php_ini%"
(echo ;https://xdebug.org/docs/all_settings#mode)>>"%php_ini%"
(echo xdebug.mode=off)>>"%php_ini%"
(echo xdebug.start_with_request=yes)>>"%php_ini%"
(echo ;The following overrides allow profiler, gc stats and traces to work correctly in ZTS)>>"%php_ini%"
(echo xdebug.profiler_output_name=cachegrind.%%s.%%p.%%r)>>"%php_ini%"
(echo xdebug.gc_stats_output_name=gcstats.%%s.%%p.%%r)>>"%php_ini%"
(echo xdebug.trace_output_name=trace.%%s.%%p.%%r)>>"%php_ini%"

call :pm-echo "Xdebug is included, but disabled by default. To enable it, change 'xdebug.mode' in your php.ini file."

REM TODO: more entries

cd /D ..\..

REM this includes all the stuff necessary to run anything needing 2015, 2017 and 2019 in one package
call :pm-echo "Downloading Microsoft Visual C++ Redistributable 2015-2019"
wget https://aka.ms/vs/16/release/vc_redist.x64.exe -nv -O vc_redist.x64.exe >>"%log_file%" 2>&1 || exit 1

call :pm-echo "Checking PHP build works..."
bin\php\php.exe --version >>"%log_file%" 2>&1 || call :pm-fatal-error "PHP build isn't working"
bin\php\php.exe -m >>"%log_file%" 2>&1

call :pm-echo "Packaging build..."
set package_filename=php-%PHP_DISPLAY_VER%-%VC_VER%-%ARCH%.zip
if exist %package_filename% del /s /q %package_filename%
7z a -bd %package_filename% bin vc_redist.x64.exe >nul || call :pm-fatal-error "Failed to package the build"

call :pm-echo "Created build package %package_filename%"
call :pm-echo "Moving debugging symbols to output directory..."
move "%SOURCES_PATH%\php-src\%ARCH%\%OUT_PATH_REL%_TS\php-debug-pack*.zip" .
call :pm-echo "Done?"

exit 0

:check-vs-exists
if exist "C:\Program Files (x86)\Microsoft Visual Studio\%~1" (
    set VS_VER=%~2
    set VS_YEAR=%~1
    set CMAKE_TARGET=Visual Studio %~2 %~1
    call :pm-echo "Found Visual Studio %~1"
    exit /B 0
) else (
    call :pm-echo "DID NOT FIND VS %~1"
    set VS_VER=
    set VS_YEAR=
    exit /B 1
)

:get-extension-zip-from-github:
call :pm-echo " - %~1: downloading %~2..."
call :get-zip https://github.com/%~3/%~4/archive/%~2.zip || exit /B 1
move %~4-%~2 %~1 >>"%log_file%" 2>&1 || exit /B 1
exit /B 0


:get-zip
setlocal
PATH=%ORIG_PATH%
wget "%~1" -nv -O temp.zip >>"%log_file%" 2>&1 || call :pm-fatal-error "Failed to download %~1"
7z x -y temp.zip >nul || exit /B 1
del /s /q temp.zip >nul || exit /B 1
endlocal
@echo off
exit /B 0

:pm-fatal-error
call :pm-echo-error "%~1 - check compile.log for details"
exit 1

:pm-echo-error
call :pm-echo "[ERROR] %~1"
exit /B 0

:pm-echo
echo [PocketMine] %~1
echo [PocketMine] %~1 >>"%log_file%" 2>&1
exit /B 0
