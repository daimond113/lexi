# lexi_cli

A CLI for pushing [Lexi](https://pesde.dev/packages/daimond113/lexi) lexicons.

## Usage

`lexi_cli <universe id> <path to lexicon.luau>`

The API token requires the `legacy-universe:manage` permission and is read from
the `LEXI_AUTH_TOKEN` env variable. For convenience, the CLI will load .env
files.

The file is run with a custom mini environment, notable changes:
- require always returns lexi, the path is completely ignored
- Instances are simple indexable/callable metametatables

This is why lexicons must be defined in their own file.

This CLI supports roblox-ts generated output.

## Cloud localization entries aren't used/are outdated

This is a [Roblox bug](https://devforum.roblox.com/t/cloud-localization-table-entries-not-usable/3927603?u=daimond113).
As a workaround, you can create an entry such as `lexi_{os.time()}` which should
force the entries to update.