# geode-xmake

A WIP `xmake` setup for writing geode mods

Has support for:

- `xmake` and `cmake` dependency mixing
- full cross-platform mod building

## Setup

1. Create an `xmake` project if you don't already have one:

```sh
xmake create -l c++ yourprojectname
```

2. Write and save a valid Geode `mod.json` ([How to configure your mod (Geode docs)](https://docs.geode-sdk.org/mods/configuring))
3. Copy `geode.lua` from here into your project
4. Add this to your projects `xmake.lua`:

```lua
includes("geode.lua")

target("<author>.<id>")
do
	add_rules("geode.mod")
	add_files("src/*.cpp")
end
```

5. No step 5, you're done. Just use `xmake` as you usually would.
