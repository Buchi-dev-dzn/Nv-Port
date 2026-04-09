# nv-port

> A Neovim plugin that ...

## Features

- ...

## Installation

### lazy.nvim

```lua
{
    "your-username/nv-port",
    opts = {},
}
```

### packer.nvim

```lua
use {
    "your-username/nv-port",
    config = function()
        require("nv-port").setup()
    end,
}
```

## Configuration

```lua
require("nv-port").setup({
    -- Example option (default: "default")
    option = "default",
})
```

## Commands

| Command    | Description      |
|------------|------------------|
| `:NvPort`  | Example command  |

## Development

### Requirements

- Neovim >= 0.9.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (for tests)
- [StyLua](https://github.com/JohnnyMorganz/StyLua) (for formatting)
- [selene](https://github.com/Kampfkarren/selene) (for linting)

### Commands

```sh
make test          # Run tests
make lint          # Run selene linter
make format        # Format code with StyLua
make format-check  # Check formatting without writing
```

## License

MIT
