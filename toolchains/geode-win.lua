toolchain("geode-win")
do
	set_kind("standalone")
	set_description("Geode Windows cross-compilation toolchain (clang-cl + lld-link)")

	on_check(function(toolchain)
		local xdg_data = os.getenv("XDG_DATA_HOME") or path.join(os.getenv("HOME") or "~", ".local/share")
		local cross = os.getenv("GEODE_CROSS_TOOLS") or path.join(xdg_data, "Geode/cross-tools/clang-msvc-sdk")

		local splat = path.join(cross, "splat")
		if not os.isdir(splat) then
			cprint("${yellow}[geode-win] Windows SDK (splat) not found at %s", splat)
			cprint("${yellow}[geode-win] Run: geode sdk install-linux")
			return false
		end

		toolchain:config_set("cross_tools", cross)
		toolchain:config_set("splat_dir", splat)
		return true
	end)

	on_load(function(toolchain)
		local cross = toolchain:config("cross_tools")
		local splat = toolchain:config("splat_dir")

		toolchain:set("toolset", "cc", "clang-cl")
		toolchain:set("toolset", "cxx", "clang-cl")
		toolchain:set("toolset", "ld", "lld-link")
		toolchain:set("toolset", "sh", "lld-link")
		toolchain:set("toolset", "ar", "llvm-lib")
		toolchain:set("toolset", "rc", "llvm-rc")
		toolchain:set("toolset", "mt", "llvm-mt")

		toolchain:add(
			"cxflags",
			"--target=x86_64-windows-msvc",
			"-fms-compatibility-version=19.37",
			"/EHsc",
			"/Zc:__cplusplus",
			"/std:c++latest",
			"-D_CRT_SECURE_NO_WARNINGS",
			"-Wno-unused-command-line-argument"
		)
		local msvc_inc = path.join(splat, "crt/include")
		local winsdk = path.join(splat, "sdk/include")
		local msvc_lib = path.join(splat, "crt/lib/x86_64")
		local winsdk_ucrt = path.join(splat, "sdk/lib/ucrt/x86_64")
		local winsdk_um = path.join(splat, "sdk/lib/um/x86_64")

		for _, dir in ipairs({
			msvc_inc,
			path.join(winsdk, "ucrt"),
			path.join(winsdk, "shared"),
			path.join(winsdk, "um"),
			path.join(winsdk, "winrt"),
		}) do
			toolchain:add("cxflags", "-imsvc" .. dir, { force = true })
		end
		toolchain:add("ldflags", "-libpath:" .. msvc_lib, "-libpath:" .. winsdk_ucrt, "-libpath:" .. winsdk_um)
		toolchain:add("shflags", "-libpath:" .. msvc_lib, "-libpath:" .. winsdk_ucrt, "-libpath:" .. winsdk_um)

		toolchain:add(
			"syslinks",
			"user32",
			"kernel32",
			"shell32",
			"ole32",
			"crypt32",
			"advapi32",
			"gdi32",
			"delayimp",
			"ws2_32",
			"opengl32"
		)

		toolchain:set("plat", "windows")
		toolchain:set("arch", "x64")
	end)
end
