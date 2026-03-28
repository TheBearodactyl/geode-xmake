# geode-xmake

A WIP xmake setup for writing geode mods

## how to use (for now)

clone this repo, make a new directory in it with a mod.json and some source code, then plop this into an `xmake.lua`:
```lua
includes("../geode.lua")

set_config("plat", "windows")
set_config("arch", "x64")
set_config("toolchain", "geode-win")

target("<author>.<mod>")
do
    add_rules("geode.mod")
    add_files("src/*.cpp")
    set_targetdir("$(builddir)/$(plat)/$(arch)/$(mode)")
    set_policy("build.ccache", false)
end
```

i will be making it easier to make a mod with this later, but for now you need to do the above
