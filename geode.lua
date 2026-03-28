local geode_dir = os.scriptdir()

add_repositories("geode-xmake-repo " .. geode_dir)
add_requires("geode-sdk")

includes(path.join(geode_dir, "toolchains/geode-win.lua"))

add_rules("mode.debug", "mode.release")
set_defaultmode("release")
set_languages("cxx23")

rule("geode.mod")
on_load(function(target)
	target:add("packages", "geode-sdk")
	target:set("kind", "shared")
	target:set("prefixname", "")
	if is_plat("windows") then
		target:add("cxflags", "/std:c++latest", { force = true })
	else
		target:set("languages", "cxx23")
	end

	if is_plat("windows") then
		target:add("shflags", "/NOEXP", { force = true })
		target:set("policy", "check.auto_ignore_flags", false)
	end

	local mod_json_path = path.join(target:scriptdir(), "mod.json")
	if os.isfile(mod_json_path) then
		local raw = io.readfile(mod_json_path)
		local mod_id = raw and raw:match('"id"%s*:%s*"([^"]+)"')
		if mod_id then
			target:set("filename", mod_id)
			target:data_set("geode.mod_id", mod_id)
		end
	end
end)

after_build(function(target)
	import("lib.detect.find_tool")

	local mod_json_path = path.join(target:scriptdir(), "mod.json")
	if not os.isfile(mod_json_path) then
		cprint("${yellow}[geode.mod] mod.json not found — skipping .geode packaging")
		return
	end

	local raw = io.readfile(mod_json_path)
	local mod_id = raw and raw:match('"id"%s*:%s*"([^"]+)"')
	if not mod_id then
		cprint("${yellow}[geode.mod] Could not read 'id' from mod.json — skipping packaging")
		return
	end

	local geode_cli = find_tool("geode", {
		paths = {
			path.join(os.getenv("HOME") or "~", ".local/bin"),
			"/usr/local/bin",
		},
	})
	if not geode_cli then
		cprint("${yellow}[geode.mod] Geode CLI not found — .geode archive NOT created")
		cprint("${yellow}[geode.mod] Install it from: https://github.com/geode-sdk/cli/releases")
		return
	end

	local binary = target:targetfile()
	local out_dir = target:targetdir()
	local geode_file = path.join(out_dir, mod_id .. ".geode")

	cprint("${cyan}[geode.mod] Packaging %s…", path.filename(geode_file))
	local ok = try({
		function()
			os.execv(geode_cli.program, {
				"package",
				"new",
				target:scriptdir(),
				"--binary",
				binary,
				"--output",
				geode_file,
			})
			return true
		end,
		catch({
			function(err)
				cprint("${red}[geode.mod] geode package new failed: %s", tostring(err))
				return false
			end,
		}),
	})
	if ok and os.isfile(geode_file) then
		cprint("${green}[geode.mod] Created %s", geode_file)
	end
end)
rule_end()
