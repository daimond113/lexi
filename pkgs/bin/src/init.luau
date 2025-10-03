local net = require('@lune/net')
local process = require('@lune/process')
local serde = require('@lune/serde')
local fs = require('@lune/fs')
local luau = require('@lune/luau')
local stdio = require('@lune/stdio')
local dotenv = require('@self/dotenv')

dotenv()

local API_KEY = process.env.LEXI_AUTH_TOKEN

local game_id = tonumber(process.args[1])
local lexicon_read, lexicon_contents = pcall(fs.readFile, process.args[2])

if game_id == nil or API_KEY == nil or not lexicon_read then
	print('Usage:')
	print('lexi_cli <game id> <path to lexicon>')
	print('\tLEXI_AUTH_TOKEN environment variable')
	process.exit(1)
	return nil
end

local base = 'https://apis.roblox.com/legacy-localization-tables'

local response = net.request({
	url = `{base}/v1/autolocalization/games/{game_id}/autolocalizationtable`,
	-- why?
	method = 'POST',
	headers = {
		['x-api-key'] = API_KEY,
	},
})
if not response.ok then
	error(stdio.format({ status = response.statusCode, body = response.body }))
end

local table_id = serde.decode('json', response.body).autoLocalizationTableId

local remote_entries = {}
local cursor: string?

repeat
	response = net.request({
		url = `{base}/v1/localization-table/tables/{table_id}/entries`,
		query = {
			gameId = tostring(game_id),
			cursor = cursor :: string,
		},
		method = 'GET',
		headers = {
			['x-api-key'] = API_KEY,
		},
	})
	if not response.ok then
		error(stdio.format({ status = response.statusCode, body = response.body }))
	end

	local body = serde.decode('json', response.body)
	cursor = body.nextPageCursor

	table.move(body.data, 1, #body.data, #remote_entries + 1, remote_entries)
until cursor == nil

local context_mt = {}

local fake_instance
fake_instance = setmetatable({}, {
	__index = function()
		return fake_instance
	end,
	__call = function()
		return fake_instance
	end,
})

local require_mock
require_mock = function()
	return {
		lexicon = function(locale, entries)
			return { locale = locale, entries = entries }
		end,
		context = function(source)
			return function(context)
				return setmetatable({ source = source, context = context }, context_mt)
			end
		end,

		-- TS
		import = require_mock,
	}
end

local lexicon_bytecode = luau.compile(lexicon_contents)
local lexicon: { locale: string, entries: { [string]: unknown } } = luau.load(lexicon_bytecode, {
	environment = {
		require = require_mock,
		script = fake_instance,
		game = fake_instance,
	},
})()

local lexicon_entries = {} :: { [string]: { source: string, context: string } }

local function recurse(entry: unknown, key: string)
	local source = ''
	local context = ''

	if getmetatable(entry :: any) == context_mt then
		source = (entry :: { source: string }).source
		context = (entry :: { context: string }).context
	elseif type(entry) == 'table' then
		for inner_key, inner in entry do
			recurse(inner, `{key}.{inner_key}`)
		end

		return
	else
		source = entry :: string
	end

	lexicon_entries[key] = { source = source, context = context }
end

for key, entry in lexicon.entries do
	recurse(entry, key)
end

local delete_entries = {} :: { unknown }
local create_entries = {} :: { unknown }

for _, entry in remote_entries do
	local lexicon_value = lexicon_entries[entry.identifier.key]
	lexicon_entries[entry.identifier.key] = nil
	if
		lexicon_value
		and (lexicon_value.source == entry.identifier.source and lexicon_value.context == entry.identifier.context)
	then
		continue
	end

	table.insert(delete_entries, {
		identifier = entry.identifier,
		translations = entry.translations,
		delete = true,
	})

	if lexicon_value then
		table.insert(create_entries, {
			identifier = {
				key = entry.identifier.key,
				context = lexicon_value.context,
				source = lexicon_value.source,
			},
			translations = entry.translations,
			metadata = entry.metadata,
		})
	end
end

for key, value in lexicon_entries do
	table.insert(create_entries, {
		identifier = {
			key = key,
			context = value.context,
			source = value.source,
		},
	})
end

local function do_request(entries: { unknown })
	if next(entries) == nil then
		return
	end

	local request_body = serde.encode('json', {
		name = 'Unused Translation Table Name Placeholder',
		entries = entries,
	}, true)

	response = net.request({
		url = `{base}/v1/localization-table/tables/{table_id}`,
		query = {
			gameId = tostring(game_id),
		},
		method = 'PATCH',
		body = request_body,
		headers = {
			['x-api-key'] = API_KEY,
			['Content-Type'] = 'application/json',
		},
	})
	if not response.ok then
		error(stdio.format({ status = response.statusCode, body = response.body }))
	end

	local body = serde.decode('json', response.body)
	if #body.failedEntriesAndTranslations ~= 0 then
		error(stdio.format(body.failedEntriesAndTranslations))
	end
end

do_request(delete_entries)
do_request(create_entries)

print('pushed!')

return nil
