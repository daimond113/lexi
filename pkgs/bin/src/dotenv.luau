local fs = require('@lune/fs')
local process = require('@lune/process')
local serde = require('@lune/serde')

local function dotenv()
	local success, content = pcall(fs.readFile, `{process.cwd}/.env`)

	if success and type(content) == 'string' then
		success, content = pcall(serde.decode, 'toml', content)

		if success and content then
			for key, value in content do
				process.env[key] = value
			end
		else
			warn('unable to parse .env file: ', content)
		end
	end

	return process.env
end

return dotenv
