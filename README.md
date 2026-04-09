# NvPort 🚀

> The ultimate Neovim environment portability tool for macOS, Linux, and Windows.

NvPort allows you to seamlessly export your Neovim configuration into a portable ZIP archive and restore it on another machine. Whether you are switching between machines or setting up a new environment, NvPort ensures a consistent editing experience across different operating systems.

---

## ✨ Features

- **📦 Portable Export**: Packages your Lua configuration, plugin lockfile, and dynamic dependency metadata.
- **🩺 Environment Doctor**: A modern floating UI to diagnose missing external tools (git, node, ripgrep, etc.) and OS-specific setup.
- **🔍 Portability Analyzer**: Automatically scans your settings for hardcoded paths or OS-specific commands that might break on other systems.
- **🛡️ Safe Import**: Features 2-step verification (Preview -> Confirm) with warnings about OS mismatches.
- **🌐 Cross-OS Support**: Tailored adapters for macOS, Linux, and Windows (PowerShell) handling path differences and ZIP operations.

## 🚀 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "your-username/nv-port",
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

- [x] Phase 1: MVP (Export/Import/Doctor/Analyzer)
- [ ] Phase 2: Security & Filtering (Exclude secrets, `.env`, etc.)
- [ ] Phase 3: Automation & Backup (Auto-backup during import)
- [ ] Phase 4: Full Portability (Standalone installer scripts)
- [ ] Phase 5: CLI Mode (Binary implementation for easy bootstrapping)

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

MIT © [Your Name]
