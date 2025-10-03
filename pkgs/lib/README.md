# lexi

Localisation for Vide, simplified.

Lexi allows you to define your text and get typed sources for use with [Vide](https://github.com/centau/vide).
It is designed with cloud translations in mind, and so has a CLI with pushing
functionality, allowing your code to be the source of truth for text in your
games.

As it uses manual translation, it is important to disable `AutoLocalize` on
your text.

## Installation

Lexi and the [CLI](https://pesde.dev/packages/daimond113/lexi_cli) are available
on [pesde](https://pesde.dev).

```sh
pesde add -t roblox  daimond113/lexi
pesde add -d -t lune daimond113/lexi_cli
```

Only the library is available on [npm](https://www.npmjs.com/) for
[roblox-ts](https://roblox-ts.com/).

```sh
npm i @rbxts/lexi
```

## Example

Lexi is designed for use with the new solver. Additionally, it is highly
recommended to use `FFlagDebugLuauStringSingletonBasedOnQuotes`, otherwise you
will need to cast your strings to singletons.

Because Lexi runs your module, it is required that you define your lexicon in
its own module.

```luau
local lexi = require(game:GetService("ReplicatedStorage").roblox_packages.lexi)
local lexicon = lexi.lexicon
local context = lexi.context

return lexicon("en-us", {
    hello = 'Hello there',
    pets = {
        hamster = context 'This is my ugly old hamster' "The speaker loves the hamster."
    },
    goodbye_player = 'Goodbye {player}, it is sad to leave you at {when:datetime}',
})
```

```luau
create "TextLabel" {
    AutoLocalize = false,
    Text = lexicon.hello,
}

create "TextLabel" {
    AutoLocalize = false,
    Text = lexicon.pets.hamster,
}

create "TextLabel" {
    AutoLocalize = false,
    Text = function()
        return lexicon.goodbye_player({ player = local_player.Name, when = time_source() })
    end,
}
```

```ts
import { lexicon, context } from "@rbxts/lexi"

export = lexicon("en-us", {
    hello: 'Hello there',
    pets: {
        hamster: context('This is my ugly old hamster')("The speaker still loves the hamster.")
    },
    goodbyePlayer: 'Goodbye {player}, it is sad to leave you at {when:datetime}',
})
```

```tsx
<textlabel
    AutoLocalize={false}
    Text={lexicon.hello}
/>
<textlabel
    AutoLocalize={false}
    Text={lexicon.pets.hamster}
/>
<textlabel
    AutoLocalize={false} 
    Text={() => lexicon.goodbyePlayer({ player: localPlayer.Name, when: timeSource() })}
/>
```