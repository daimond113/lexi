local fs = require('@lune/fs')

pcall(fs.removeDir, 'dist')
fs.copy('src', 'dist/lib')
fs.writeDir('dist/roblox_packages')
fs.writeFile(
	'dist/roblox_packages/vide.luau',
	[[
local TS = _G[script.Parent.Parent.lib]
return TS.import(script.Parent.Parent.lib, TS.getModule(script.Parent.Parent.lib, "@rbxts", "vide").src)]]
)
