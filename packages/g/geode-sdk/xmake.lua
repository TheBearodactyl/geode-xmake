package("geode-sdk")
do
	set_description("Geode Mod SDK for Geometry Dash")
	set_homepage("https://geode-sdk.org")
	set_license("LGPL-2.1")

	add_configs("sdk_path", {
		description = "Absolute path to the Geode SDK checkout (default: $GEODE_SDK).",
		default = "",
	})
	add_configs("gd_version", {
		description = "Geometry Dash version to target.",
		default = "2.2081",
	})
	add_configs("cross_tools", {
		description = "Path to clang-msvc-sdk for Linux→Windows cross-compilation "
			.. "(default: ~/.local/share/Geode/cross-tools/clang-msvc-sdk).",
		default = "",
	})
	add_configs("skip_bindings_build", {
		description = "Skip compiling GeodeBindings during install. "
			.. "You must then add the bindings source files to your target manually.",
		default = false,
		type = "boolean",
	})

	on_load(function(package)
		local sdk_path = package:config("sdk_path")
		if sdk_path == "" then
			sdk_path = os.getenv("GEODE_SDK") or ""
		end

		local gd_ver = package:config("gd_version")
		local gd_comp = gd_ver:gsub("%.", "")

		package:add(
			"includedirs",
			"include",
			"include/Geode/cocos/include",
			"include/Geode/cocos/extensions",
			"include/Geode/fmod",
			"bindings"
		)

		package:add(
			"defines",
			"GEODE_GD_VERSION=" .. gd_ver,
			"GEODE_COMP_GD_VERSION=" .. gd_comp,
			'GEODE_GD_VERSION_STRING="' .. gd_ver .. '"',
			"MAT_JSON_DYNAMIC=1"
		)

		package:add("cxxflags", "-Werror=return-type")

		if package:is_plat("windows") then
			package:add("defines", "NOMINMAX", "_HAS_ITERATOR_DEBUGGING=0", "ISOLATION_AWARE_ENABLED=1", "GLEW_NO_GLU")
			package:add("linkdirs", "lib", "lib/win64")
			package:add(
				"links",
				"Geode",
				"geode-entry",
				"GeodeBindings",
				"fmt",
				"asp",
				"arc",
				"libcocos2d",
				"libExtensions",
				"glew32",
				"fmod",
				"delayimp",
				"ws2_32",
				"opengl32"
			)
			package:add("shflags", "/DELAYLOAD:libcocos2d.dll", "/DELAYLOAD:libExtensions.dll")
		elseif package:is_plat("macosx") then
			package:add("defines", "CommentType=CommentTypeDummy", "GL_SILENCE_DEPRECATION")
			package:add("linkdirs", "lib", "lib/macos")
			package:add("links", "geode-entry", "GeodeBindings", "fmt", "asp", "arc")
			package:add("frameworks", "Cocoa", "OpenGL", "SystemConfiguration")
			package:add("linkfiles", package:installdir("lib/macos/libfmod.dylib"))
		elseif package:is_plat("iphoneos") then
			package:add("defines", "GLES_SILENCE_DEPRECATION")
			package:add("linkdirs", "lib")
			package:add("links", "geode-entry", "GeodeBindings", "fmt", "asp", "arc")
			package:add(
				"frameworks",
				"OpenGLES",
				"UIKit",
				"Foundation",
				"AVFoundation",
				"CoreGraphics",
				"GameController"
			)
		elseif package:is_plat("android") then
			local arch_suffix = package:is_arch("arm64-v8a") and "android64" or "android32"
			package:add("linkdirs", "lib", "lib/" .. arch_suffix)
			package:add(
				"links",
				"geode-entry",
				"GeodeBindings",
				"fmt",
				"asp",
				"arc",
				"libcocos2dcpp",
				"libfmod",
				"c",
				"unwind",
				"GLESv2",
				"log"
			)
		end
	end)

	on_install("windows|x64", "windows|x86", "macosx", "iphoneos", "android", function(package)
		local sdk_path = package:config("sdk_path")
		if sdk_path == "" then
			sdk_path = os.getenv("GEODE_SDK") or ""
		end
		assert(
			sdk_path ~= "",
			"[geode-sdk] SDK path is empty. " .. "Set the GEODE_SDK environment variable or pass sdk_path config."
		)
		assert(os.isdir(sdk_path), "[geode-sdk] SDK directory not found: " .. sdk_path)

		local gd_version = package:config("gd_version")
		local sdk_version = (io.readfile(path.join(sdk_path, "VERSION")) or "5.4.1"):trim()
		local cache = package:cachedir()
		local cpm_cache = path.join(cache, "cpm")

		cprint(
			"${cyan}[geode-sdk] Installing SDK %s for %s/%s (GD %s)",
			sdk_version,
			package:plat(),
			package:arch(),
			gd_version
		)

		cprint("${cyan}[geode-sdk] Copying SDK headers…")
		os.cp(path.join(sdk_path, "loader/include/*"), package:installdir("include"))

		cprint("${cyan}[geode-sdk] Copying loader binary…")
		local bin_dir = path.join(sdk_path, "bin", sdk_version)
		if package:is_plat("windows") then
			local geode_lib = path.join(bin_dir, "Geode.lib")
			assert(
				os.isfile(geode_lib),
				"[geode-sdk] Pre-built Geode.lib not found at "
					.. geode_lib
					.. ". Run 'geode sdk install-binaries' first."
			)
			os.cp(geode_lib, package:installdir("lib"))
			local link_win64 = path.join(sdk_path, "loader/include/link/win64")
			if os.isdir(link_win64) then
				os.cp(path.join(link_win64, "*.lib"), package:installdir("lib/win64"))
			end
		elseif package:is_plat("macosx") then
			local dylib = path.join(bin_dir, "macos", "Geode.dylib")
			if os.isfile(dylib) then
				os.cp(dylib, package:installdir("lib/macos"))
			end
			local link_mac = path.join(sdk_path, "loader/include/link/macos")
			if os.isdir(link_mac) then
				os.cp(path.join(link_mac, "*.dylib"), package:installdir("lib/macos"))
			end
		elseif package:is_plat("android") then
			local arch_suffix = package:is_arch("arm64-v8a") and "android64" or "android32"
			local link_android = path.join(sdk_path, "loader/include/link", arch_suffix)
			if os.isdir(link_android) then
				os.cp(path.join(link_android, "*.so"), package:installdir("lib/" .. arch_suffix))
			end
		end

		local bindings_dir = path.join(cache, "bindings")
		local bindings_src = path.join(bindings_dir, "bindings", gd_version)
		if not os.isdir(bindings_src) then
			cprint("${cyan}[geode-sdk] Cloning geode-sdk/bindings…")
			if os.isdir(bindings_dir) then
				os.execv("git", { "-C", bindings_dir, "pull", "--depth=1", "--rebase" })
			else
				os.execv("git", {
					"clone",
					"--depth=1",
					"https://github.com/geode-sdk/bindings.git",
					bindings_dir,
				})
			end
		else
			cprint("${cyan}[geode-sdk] Bindings already cached")
		end

		local codegen_dir = path.join(cache, "codegen-bin")
		os.mkdir(codegen_dir)
		local codegen_bin = path.join(codegen_dir, is_host("windows") and "Codegen.exe" or "Codegen")
		if not os.isfile(codegen_bin) then
			local suffix
			if is_host("windows") then
				suffix = "win.exe"
			elseif is_host("macosx") then
				suffix = "mac"
			else
				suffix = "linux"
			end
			local url = "https://github.com/geode-sdk/bindings/releases/download/codegen/geode-codegen-" .. suffix
			cprint("${cyan}[geode-sdk] Downloading Codegen (%s)…", suffix)
			import("net.http")
			http.download(url, codegen_bin)
			if not is_host("windows") then
				os.execv("chmod", { "+x", codegen_bin })
			end
		end

		local plat_map = {
			windows = "Win64",
			macosx = "MacOS",
			iphoneos = "iOS",
		}
		local plat_codegen = plat_map[package:plat()]
		if not plat_codegen then
			plat_codegen = package:is_arch("arm64-v8a") and "Android64" or "Android32"
		end

		local codegen_out = path.join(cache, "codegen-out-" .. plat_codegen)
		local gen_hdr = path.join(codegen_out, "Geode", "GeneratedBinding.hpp")
		if not os.isfile(gen_hdr) then
			os.mkdir(codegen_out)
			cprint("${cyan}[geode-sdk] Running Codegen for %s…", plat_codegen)
			os.execv(codegen_bin, { plat_codegen, bindings_src, codegen_out })
		else
			cprint("${cyan}[geode-sdk] Using cached Codegen output for %s", plat_codegen)
		end

		cprint("${cyan}[geode-sdk] Installing generated binding headers…")
		local gen_geode = path.join(codegen_out, "Geode")
		os.cp(path.join(gen_geode, "*.hpp"), package:installdir("bindings/Geode"))
		os.cp(path.join(gen_geode, "binding/*.hpp"), package:installdir("bindings/Geode/binding"))
		os.cp(path.join(gen_geode, "modify/*.hpp"), package:installdir("bindings/Geode/modify"))
		local bnd_inc = path.join(bindings_dir, "bindings/include")
		if os.isdir(bnd_inc) then
			os.cp(path.join(bnd_inc, "*"), package:installdir("bindings"))
		end

		os.cp(path.join(gen_geode, "GeneratedSource.cpp"), package:installdir("bindings-src"))
		if os.isdir(path.join(gen_geode, "source")) then
			os.cp(path.join(gen_geode, "source/*.cpp"), package:installdir("bindings-src/source"))
		end
		if os.isdir(path.join(bindings_src, "inline")) then
			os.cp(path.join(bindings_src, "inline/*.cpp"), package:installdir("bindings-src/inline"))
		end

		if not package:config("skip_bindings_build") then
			local cross_tools = package:config("cross_tools")
			if cross_tools == "" then
				local xdg = os.getenv("XDG_DATA_HOME") or path.join(os.getenv("HOME") or "~", ".local/share")
				cross_tools = path.join(xdg, "Geode/cross-tools/clang-msvc-sdk")
			end

			local toolchain_file = nil
			local extra_args = {}
			if package:is_plat("windows") then
				toolchain_file = path.join(cross_tools, "clang-cl-msvc.cmake")
				local splat_dir = path.join(cross_tools, "splat")
				assert(
					os.isdir(splat_dir),
					"[geode-sdk] Windows SDK (splat) not found at " .. splat_dir .. ". Run: geode sdk install-linux"
				)
				table.insert(extra_args, "-DSPLAT_DIR=" .. splat_dir)
				table.insert(extra_args, "-DHOST_ARCH=x86_64")
			end

			local cmake_src = package:builddir() .. "/cmake-src"
			local cmake_build = package:builddir() .. "/cmake-build"
			os.mkdir(cmake_src)
			os.mkdir(cmake_build)

			io.writefile(
				path.join(cmake_src, "CMakeLists.txt"),
				string.format(
					[[
cmake_minimum_required(VERSION 3.25 FATAL_ERROR)
project(GeodeXMakeHelper)

set(GEODE_BINDINGS_REPO_PATH "%s" CACHE PATH "" FORCE)
set(CPM_SOURCE_CACHE          "%s" CACHE PATH "" FORCE)
set(GEODE_DISABLE_CLI_CALLS   ON   CACHE BOOL "" FORCE)
set(GEODE_DONT_INSTALL_MODS   ON   CACHE BOOL "" FORCE)

add_subdirectory("%s" "${CMAKE_BINARY_DIR}/geode-sdk-internal")

add_library(geode-entry STATIC "%s/entry.cpp")
target_link_libraries(geode-entry PUBLIC geode-sdk)

install(TARGETS GeodeBindings fmt asp arc geode-entry ARCHIVE DESTINATION lib)
]],
					bindings_dir,
					cpm_cache,
					sdk_path,
					sdk_path
				)
			)

			cprint("${cyan}[geode-sdk] CMake configure…")
			local configure_args = {
				cmake_src,
				"-B",
				cmake_build,
				"-DCMAKE_BUILD_TYPE=Release",
			}
			if toolchain_file and os.isfile(toolchain_file) then
				table.insert(configure_args, "-DCMAKE_TOOLCHAIN_FILE=" .. toolchain_file)
			end
			for _, a in ipairs(extra_args) do
				table.insert(configure_args, a)
			end
			os.execv("cmake", configure_args)

			local ncpu = math.max(1, os.cpuinfo().ncpu or 1)
			cprint("${cyan}[geode-sdk] CMake build (GeodeBindings + fmt + asp + arc + geode-entry, %d jobs)…", ncpu)
			os.execv("cmake", {
				"--build",
				cmake_build,
				"--config",
				"Release",
				"--target",
				"GeodeBindings",
				"fmt",
				"asp",
				"arc",
				"geode-entry",
				"-j",
				tostring(ncpu),
			})

			cprint("${cyan}[geode-sdk] Installing built libraries…")
			local cmake_install_prefix = package:installdir()
			os.execv("cmake", {
				"--install",
				cmake_build,
				"--config",
				"Release",
				"--prefix",
				cmake_install_prefix,
				"--component",
				"Unspecified",
			})

			local fmt_src = path.join(cmake_build, "_deps/fmt-src")
			if not os.isdir(fmt_src) then
				for _, d in ipairs(os.dirs(path.join(cpm_cache, "fmt/*")) or {}) do
					fmt_src = d
					break
				end
			end
			if fmt_src and os.isdir(path.join(fmt_src, "include")) then
				os.cp(path.join(fmt_src, "include/*"), package:installdir("include"))
			end
		end

		cprint("${cyan}[geode-sdk] Installing dependency headers…")

		local function install_dep_headers(name, repo, tag)
			local cpm_dir = path.join(cpm_cache, name)
			if os.isdir(cpm_dir) then
				for _, d in ipairs(os.dirs(cpm_dir .. "/*") or {}) do
					local inc = path.join(d, "include")
					if os.isdir(inc) then
						os.cp(path.join(inc, "*"), package:installdir("include"))
						return
					end
				end
			end
			local dep_dir = path.join(cache, "deps", name)
			if not os.isdir(dep_dir) then
				local args = { "clone", "--depth=1" }
				if tag then
					table.insert(args, "-b")
					table.insert(args, tag)
				end
				table.insert(args, "https://github.com/" .. repo .. ".git")
				table.insert(args, dep_dir)
				os.execv("git", args)
			end
			local inc = path.join(dep_dir, "include")
			if os.isdir(inc) then
				os.cp(path.join(inc, "*"), package:installdir("include"))
			end
		end

		install_dep_headers("result", "geode-sdk/result", "v1.4.1")
		install_dep_headers("json", "geode-sdk/json", "v3.3.0")
		install_dep_headers("nontype_functional", "geode-sdk/nontype_functional", nil)
		install_dep_headers("tuliphook", "geode-sdk/TulipHook", "v3.1.11")
		install_dep_headers("asp2", "dankmeme01/asp2", nil)
		install_dep_headers("arc", "dankmeme01/arc", "v1.5.5")

		if package:config("skip_bindings_build") then
			install_dep_headers("fmt", "fmtlib/fmt", "12.1.0")
		else
			local fmt_cpm = path.join(cpm_cache, "fmt")
			if os.isdir(fmt_cpm) then
				for _, d in ipairs(os.dirs(fmt_cpm .. "/*") or {}) do
					local inc = path.join(d, "include")
					if os.isdir(inc) then
						os.cp(path.join(inc, "*"), package:installdir("include"))
						break
					end
				end
			end
		end

		cprint("${green}[geode-sdk] Installation complete!")
	end)
end
