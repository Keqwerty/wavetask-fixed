# org.vicko.wavetask

KDE Plasma 6 task manager with macOS-style dock zoom animation, smart launcher badges, and advanced window management features. It's based on the default task manager of KDE.

Since Plasma 6.6 does not allow direct access to org.kde.plasma.private.taskmanager, the plugin has had to be compiled, so the installation is no longer just a matter of copying but requires compilation.

![wavetask](screenshot/wavetask_1280_2.webp?raw=true "wavetask")

## Support for previous Plasma releases

Currently supported versions: 6.6, 6.7, 6.8 (Wayland).

### Migrating from Plasma 6.7 to 6.8

Rebuild and reinstall WaveTask after upgrading Plasma. The native plugin links
against Plasma libraries whose ABI changes between releases; copying the old
binary is not sufficient. Keep `plasma-desktop` installed: on 6.8 WaveTask loads
the stock Task Manager backend's embedded QML module for its shared global
shortcut dispatcher. On 6.7 the shell continues to handle Meta+number itself.

Existing widget instances and their configuration are reused. Do not delete
`plasma-org.kde.plasma.desktop-appletsrc` or recreate the dock to migrate.
Pinned launchers, grouping settings, icon size and skin settings keep their
existing keys and values.

The port follows the actual 6.7.5 → 6.8.0 upstream changes:

- [Task shortcuts moved from the shell into the Task Manager backend](https://invent.kde.org/plasma/plasma-desktop/-/commit/8cdade3d2d972b53ca01c50efe99d97a36fb7fb6).
  WaveTask joins that dispatcher rather than registering competing shortcuts
  when a stock Task Manager is also present. The 6.8 cycle/move shortcuts operate
  on individual grouped windows and persist reordered launchers.
- [Plasma's QML window previews](https://invent.kde.org/plasma/plasma-desktop/-/blob/v6.8.0/applets/taskmanager/qml/ToolTipInstance.qml)
  now use PipeWire only. The removed X11 `WindowThumbnail` type is no longer
  referenced, including in inactive components. Plasma 6.7 X11 live previews
  are no longer provided.
- [Task model roles](https://invent.kde.org/plasma/plasma-workspace/-/blob/v6.8.0/libtaskmanager/abstracttasksmodel.h)
  no longer expose window shading. Preview readiness uses the per-window
  `IsMapped` role on 6.8 and the existing geometry check on 6.7. Audio matching
  respects 6.8's normalized application IDs.
- The dock binds to its actual containment type, without relying on generated
  QML class names or delayed polling. New dock panels use the scripting API's
  `"fit"` length mode.

Build/install and isolated Wayland runtime checks were performed on Plasma
6.7.5 / Qt 6.11.2 and Plasma 6.8.0 / Qt 6.12.0. These covered persisted dock
settings, grouped and single-window live previews, task shortcuts, launcher
reordering and application audio matching/muting. Plasma 6.6 was not separately
runtime-tested.

If you need to install it on Plasma 6.5 or lower, I recommend you do it from here: https://github.com/vickoc911/org.kde.plasma.wavetask

## Packages

<details>
  <summary>openSUSE Tumbleweed (maintained by me)</summary>
  <br>
  
  ```sh
  sudo zypper ar https://download.opensuse.org/repositories/home:/vcalles/openSUSE_Tumbleweed/home:vcalles.repo
  sudo zypper refresh
  sudo zypper install wavetask
  ```
</details>
<details>
  <summary>Fedora 44, 43 (copr) (maintained by me)</summary>
  <br>
  
  ```sh
  sudo dnf copr enable vcalles/wavetask 
  sudo dnf install wavetask
  ```
</details>
<details>
  <summary>Arch Linux</summary>
  <br>

Using an AUR helper (paru, yay, etc.):

```sh
yay -S wavetask      # stable release (recommended)
yay -S wavetask-git  # bleeding edge version
```

Manual installation:

```sh
# Replace 'wavetask' with 'wavetask-git' for the bleeding edge version
git clone https://aur.archlinux.org/wavetask.git
cd wavetask
makepkg -si
```

For a local checkout of this fork, including uncommitted migration fixes, run
from the repository root:

```sh
makepkg -p PKGBUILD.local -si
```

`PKGBUILD.local` builds the current `wavetask-source/` directory and marks the
package version with `.local`. It does not clone the old `refactor` branch.
The regular `PKGBUILD` clones GitHub, so it does not include local changes.
If Plasma reports `PlasmaCore.WindowThumbnail is not a type`, the installed
widget still contains the old X11 preview code; install the rebuilt package.
The corrected local package was loaded with `plasmawindowed` and visually
checked on Plasma 6.8.0 / Qt 6.12.0.

</details>
<details>
  <summary>kubuntu 25.10 ppa launchpad  (maintained by https://github.com/Matou1306)</summary>
  <br>
  
  ```sh
sudo add-apt-repository ppa:matou1306/wavetask
sudo apt update
sudo apt install wavetask
  ```
</details>

### after installing the package add the panel for wavetask

- Right-click on your desktop.
- select "Enter edit mode"
- Go to "Layout" tab
- Select "Panel for wavetask" from the dropdown
- Click "Apply"

### After adding the panel, make these modifications

- Adjust the width to "fit to content"
- Adjust alignment to "center"
- If you want to increase the size of the icons above 46px, you need to increase the height of the panel so that the zoom is not cut off.

## Compile from source

- Install the development packages.
- Download the code from GitHub.

mkdir build && cd build

cmake .. -DCMAKE_BUILD_TYPE=Release

make -j$(nproc)

sudo make install

## Features:

- It inherits all the features of Plasma's task manager
- Zoom like in macOS
- Icon reflection
- Bouncing icons ( only in landscape mode )
- Basic skin system
- Option to select the icon size
- Option to select the zoom size
- Option to select the amplitude
- Option to disable icon reflection
- blur for default and custom skins
- Cairo Penguin ( only in landscape mode )

Skins:

- Default Plasma: draw the plasma theme
- Big Sur Light
- Big Sur Night
- IVORY glass
- No background
- Vidrio
- Tahoe
- Tahoe Dark
- coffee
- Pine
- Elegantia

What doesn't work:

- The panel has been resized to 86 pixels so that icons aren't cut off when zooming

### ☕ Buy Me a Coffee!

If this code helped you, your support allows me to continue maintenance.

[![Donate with PayPal button](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?business=XSHX7RDT74QN2&no_recurring=0&item_name=Support+my+code%3A+If+it+saved+you+time+or+helped%2C+please+consider+donating.+Your+support+keeps+this+Open+Source+project+alive%21&currency_code=USD)
