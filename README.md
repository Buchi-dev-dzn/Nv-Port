# NvPort 🚀

[![Vibe Coded](https://img.shields.io/badge/Vibe-Coded-FF69B4?style=for-the-badge&logo=aira&logoColor=white)](https://github.com/Buchi-dev-dzn/Nv-Port)
[![CI](https://github.com/Buchi-dev-dzn/Nv-Port/actions/workflows/ci.yml/badge.svg)](https://github.com/Buchi-dev-dzn/Nv-Port/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-pakage)](https://makeapullrequest.com)

> The ultimate Neovim environment portability tool for macOS, Linux, and Windows.

NvPort allows you to seamlessly export your Neovim configuration into a portable ZIP archive and restore it on another machine. Whether you are switching between machines or setting up a new environment, NvPort ensures a consistent editing experience across different operating systems.

---

## ✨ Features

- **📦 Portable Export**: Packages your Lua configuration, plugin lockfile, and dynamic dependency metadata.
- **🩺 Environment Doctor**: A modern floating UI to diagnose missing external tools (git, node, ripgrep, etc.) and OS-specific setup.
- **🔍 Portability Analyzer**: Automatically scans your settings for hardcoded paths or OS-specific commands that might break on other systems.
- **🛡️ Safe Import**: Features 2-step verification (Preview -> Confirm) with warnings about OS mismatches.
- **🌐 Cross-OS Support**: Tailored adapters for macOS, Linux, and Windows (PowerShell) handling path differences and ZIP operations.

### 🩺 Doctor UI in Action
<!-- Replace the link below with your actual screenshot! -->
![NvPort Doctor Screenshot Placeholder](https://via.placeholder.com/800x450.png?text=NvPort+Doctor+UI+Screenshot)

## 🚀 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "Buchi-dev-dzn/Nv-Port",
    opts = {
        output_dir = "~/nvport-exports", -- Directory for generated ZIPs
        default_mode = "portable",      -- instant, portable, or full
    },
}
```

## 🛠️ Usage

### 📤 Exporting your environment

Run the following command to create a backup of your current setup:

```vim
:NvPort export
```
*   **portable** (default): Optimized for moving between different OSs.
*   **instant**: Fast migration (best for same-OS copies).
*   **full**: Includes plugin source code (best for offline migration).

### 📥 Importing an environment

1.  Copy the generated ZIP to the target machine.
2.  **Preview** the import to see what will change:
    ```vim
    :NvPort import ~/path/to/archive.zip
    ```
3.  **Apply** the changes once you've reviewed the preview:
    ```vim
    :NvPort import ~/path/to/archive.zip --confirm
    ```

### 🩺 Checking environment health

Run the doctor at any time to verify your tools and paths:

```vim
:NvPort doctor
```

---

## 🗺️ Roadmap

- [x] **Phase 1: MVP** (Export/Import/Doctor/Analyzer)
- [ ] **Phase 2: Security & Filtering** (Exclude secrets, `.env`, etc.)
- [ ] **Phase 3: Automation & Backup** (Auto-backup during import)
- [ ] **Phase 4: Full Portability** (Standalone installer scripts)
- [ ] **Phase 5: CLI Mode** (Binary implementation for easy bootstrapping)

## 🤝 Contributing

Contributions are welcome! Feel free to open issues or submit pull requests to help improve NvPort.

## 💻 Development

### Requirements
- Neovim >= 0.10.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (for testing)

### Commands
```sh
make test          # Run the test suite
make lint          # Run selene linter
make format        # Format code with StyLua
```

## 📄 License

MIT © [Buchi-dev-dzn](https://github.com/Buchi-dev-dzn)
