local LocalizationService = game:GetService('LocalizationService')
local Players = game:GetService('Players')

local vide = require(script.Parent.roblox_packages.vide)

local local_player = Players.LocalPlayer

local player_locale_translator = vide.source(nil :: Translator?)
if local_player then
	local function update_localized_translator()
		local success, result =
			pcall(LocalizationService.GetTranslatorForPlayerAsync, LocalizationService, local_player)
		if success then
			player_locale_translator(result)
		else
			player_locale_translator(nil)
			warn('lexi: getting player translator failed. falling back to the source language.', result)
		end
	end

	task.spawn(update_localized_translator)
	local_player:GetPropertyChangedSignal('LocaleId'):Connect(update_localized_translator)
end

local function has_placeholders(template: string): boolean
	return string.gmatch(template, '{(.-)}')() ~= nil
end

type function get_placeholders(template: string)
	local placeholders = {}

	local placeholder_types = {
		int = types.number,
		fixed = types.number,
		num = types.number,
		HEX = types.number,
		hex = types.number,
		datetime = types.number,
		iso8601 = types.number,
		shorttime = types.number,
		shortdatetime = types.number,
		shortdate = types.number,
		translate = types.string,
	}

	for key in string.gmatch(template, '{(.-)}') do
		local name, kind = unpack(string.split(key, ':'))
		local ty: type = if kind then placeholder_types[kind] else types.string
		placeholders[types.singleton(name)] = assert(ty, `Unsupported placeholder type {kind}`)
	end

	return types.newtable(placeholders)
end

type function Lexicon(entries: type)
	assert(entries:is('table'), 'entries must be a table')

	local function recurse(entry: type)
		if entry:is('table') then
			local result = {}
			for name, entry in entry:properties() do
				result[name] = recurse(assert(entry.read))
			end
			return types.newtable(result)
		end

		local template = entry:value()
		assert(type(template) == 'string')
		local placeholders: type = get_placeholders(template)
		return types.newfunction(
			{ head = if next(placeholders:properties()) then { placeholders } else {} },
			{ head = { types.string } }
		)
	end

	local lexicon = {}
	for name, entry in entries:properties() do
		lexicon[name] = recurse(assert(entry.read))
	end

	return types.newtable(lexicon)
end

local lexi_context_mt = {}

local function context<I>(source: I & string)
	return function(context: string): I
		return setmetatable({ source = source, context = context }, lexi_context_mt) :: any
	end
end

local function try_format(translator: Translator, key: string, params: { [string]: string | number }?): string?
	local success, result = pcall(translator.FormatByKey, translator, key, params)
	if success then
		return result
	end

	return nil
end

local function lexicon<E>(source_locale: string, entries: E): Lexicon<E>
	local localization_table = Instance.new('LocalizationTable')
	localization_table.SourceLocaleId = source_locale
	localization_table.Name = 'lexi_lexicon'
	localization_table.Archivable = false
	localization_table.Parent = LocalizationService

	local lexicon_translator = localization_table:GetTranslator(source_locale)

	local function recurse(entry: string | { [string]: unknown }, key: string): unknown
		local source = ''
		local context = ''

		if getmetatable(entry) == lexi_context_mt then
			source = (entry :: { source: string }).source
			context = (entry :: { context: string }).context
		elseif type(entry) == 'table' then
			local result = {}
			for name, entry in entry do
				result[name] = recurse(entry :: any, `{key}.{name}`)
			end
			return result
		else
			source = entry
		end

		local function handle(params: { [string]: string | number }?)
			local result: string?
			local localized = player_locale_translator()

			if
				localized
				-- the ones given to us will be more up-to-date
				and localized.LocaleId ~= source_locale
			then
				result = try_format(localized, key, params)
			end

			if not result then
				result = try_format(lexicon_translator, key, params)
			end

			return result
				-- shouldn't happen 
				or entry
		end

		localization_table:SetEntryValue(key, source, context, source_locale, source)

		return if has_placeholders(source) then handle else vide.derive(handle :: never)
	end

	local lexicon = {}
	vide.root(function()
		for name, entry in entries :: { [string]: unknown } do
			lexicon[name] = recurse(entry :: any, name)
		end
	end)

	return lexicon :: any
end

return {
	context = context,
	lexicon = lexicon,
}
