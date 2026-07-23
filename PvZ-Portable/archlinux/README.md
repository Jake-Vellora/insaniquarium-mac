# Arch Linux Packaging & Testing Guide

This directory contains build scripts for Arch Linux to facilitate testing PvZ-Portable (a re-implementation engine) on various environments and configurations.

## ⚠️ Important Legal & Usage Disclaimer

**This package contains ENGINE CODE ONLY.**

To comply with copyright laws and the project's [license](../LICENSE), this build script **DOES NOT** include any game assets.
*   **You MUST own a legal copy** of *Plants vs. Zombies: Game of the Year Edition* (e.g., from Steam or EA's official website).
*   This project is for **educational and research purposes**, specifically to study cross-platform compatibility, OpenGL/SDL rendering techniques, and engine behavior on Linux architectures (x86_64, aarch64, riscv64, etc.).

## Testing Focus: Wayland vs. X11

The primary goal of this package is to test the engine's behavior under different display servers. Current known issues we are investigating:

*   **Fixed Aspect Ratio**: The engine enforces a 4:3 aspect ratio. On widescreen monitors, this results in black bars (letterboxing).
*   **~~XWayland Flickering~~** *(Fixed)*: Previously, running via XWayland could cause flickering in the black bar areas. This has been resolved by the OpenGL ES 2.0 backend refactor.
*   **Wayland Native**: Running natively on Wayland is recommended and works well across different compositors (KWin, Mutter, Hyprland, etc.).

## Build Instructions

Because we cannot distribute the game assets, you must provide them manually before building the package.

### Prerequisites

Install the base development tools:

```bash
sudo pacman -S --needed base-devel
```

### Prepare Game Assets

Locate your legally installed copy of Plants vs. Zombies 1.2.0.1073 GOTY (or 1.2.0.1096 GOTY in Steam). If you have not bought the game yet, you can purchase it on [Steam](https://store.steampowered.com/app/3590/Plants_vs_Zombies_Game_of_the_Year_Edition/) or [EA App](https://www.ea.com/games/plants-vs-zombies/plants-vs-zombies-game-of-the-year). You need two items:

> **Note on game version compatibility:** This engine is designed for **1.2.0.1073** (the standalone PopCap release). Using **1.2.0.1096** (Steam GOTY) assets works for general gameplay, but has known issues: the Almanac blue description text will not appear, the "Restart" button label may be missing, unencountered zombies show `???` instead of `(not encountered yet)`, and Crazy Dave's plant sell price displays as 1/10 of the correct value. These are caused by breaking changes in 1.2.0.1096's `LawnStrings.txt` format. **Using 1.2.0.1073 assets is recommended.**

1.  The file `main.pak`
2.  The folder `properties/`

**Common Installation Paths:**

*   **Steam (Linux/Proton):**
    `~/.steam/steam/steamapps/common/PlantsVsZombies/`
*   **Steam (Windows):**
    `C:\Program Files (x86)\Steam\steamapps\common\PlantsVsZombies\`
*   **PopCap (Windows):**
    `C:\Program Files (x86)\PopCap Games\PlantsVsZombies\` or
    `C:\Program Files\PopCap Games\PlantsVsZombies\`

**Note:** If you installed the game via Steam on Linux, it will be in the Linux path listed above. If you are copying files from a Windows partition or an external drive, look for the Windows paths.

**Packaging the Assets:**
Create a ZIP file named `Plants_vs._Zombies_1.2.0.1073_EN.zip` containing these items at the **root** of the archive.

```bash
# Example command if you are in the game directory:
7z a Plants_vs._Zombies_1.2.0.1073_EN.zip main.pak properties/
```

> **Note:** Do not put them inside a subfolder inside the zip. The `PKGBUILD` expects `main.pak` to be at the top level of the archive.

### Build and Install

1.  Copy the `Plants_vs._Zombies_1.2.0.1073_EN.zip` you just created into this `archlinux/` directory (alongside the `PKGBUILD` file).
2.  Run the build command in the `archlinux/` directory:

```bash
makepkg -si
```

This command will:
*   Compile the `PvZ-Portable` engine from source.
*   verify the integrity of your local resource zip (skipped for local files usually, but structure must match).
*   Combine the engine and your assets into an Arch Linux package.
*   Install it to your system.

### Running the Game

Launch from your application menu or terminal:

```bash
pvz-portable
```

Data is stored in `~/.local/share/io.github.wszqkzqk/PvZPortable/` by default.
