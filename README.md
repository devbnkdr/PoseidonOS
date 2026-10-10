# PoseidonOS

A phosphor-terminal theme for KDE Plasma 6, styled after old green-screen computer terminals.

- Green, amber or blue phosphor colour schemes, switchable at any time
- Matching window frames, Plasma style and Konsole profiles
- An animated, dithered wasteland-map wallpaper
- A desktop HUD with system stats, weather, a file browser, an app launcher and a terminal
- An optional CRT scanline overlay

![PoseidonOS in green](docs/screenshots/desktop-green.jpg)

| Amber | Blue |
|---|---|
| ![PoseidonOS in amber](docs/screenshots/desktop-amber.jpg) | ![PoseidonOS in blue](docs/screenshots/desktop-blue.jpg) |

*Previews rendered from the theme's own code with sample data: the user, stats and location are made up.*

Everything lives in [`poseidonos/`](poseidonos/README.md). Start there for
requirements, installation and usage.

```bash
git clone https://github.com/devbnkdr/PoseidonOS.git
cd PoseidonOS/poseidonos
./install.sh
```

The installer backs up your current desktop first, and `./uninstall.sh` puts it back.

## License

Copyright © 2026 devbnkdr. PoseidonOS is free software, released under the
[GNU General Public License v3.0](LICENSE). You can use, study, change and share it; if you
distribute a modified version, it has to stay under the GPL with its source available.

If you want to use it under other terms, for example inside a closed-source product, a separate
commercial license is available. Get in touch through GitHub.

The bundled fonts are under the SIL Open Font License 1.1.

## Disclaimer

PoseidonOS is provided **"as is", without warranty of any kind**, express or
implied, including the implied warranties of merchantability and fitness for a
particular purpose. To the extent the law allows, the author is not liable for
any damage, data loss or other harm arising from its use. Sections 15 and 16 of
the [license](LICENSE) have the full terms.

In plain words:

- **It changes your desktop.** The installer replaces your Plasma theme, colour
  schemes, window decorations and Konsole profiles, and adds a wallpaper plugin
  and widgets. It backs up your settings and takes a full desktop snapshot
  first, and `./uninstall.sh` or `./restore-desktop.sh` puts things back. Keep
  your own backup of `~/.config` and `~/.local/share` anyway.
- **Tested on KDE Plasma 6.7 with Qt 6.11.** Other versions, distros or future
  Plasma updates may break parts of it. Read the scripts before you run them.
- **The HUD talks to outside services.** The weather panel fetches the
  forecast from [Open-Meteo](https://open-meteo.com) for your location's
  coordinates (New York until you change it). Setting a location sends the ZIP
  code or city name you type to [Zippopotam.us](https://zippopotam.us) or
  Open-Meteo. The network panel pings Cloudflare's `1.1.1.1` to show latency,
  and if `checkupdates` is installed, the update count checks your package
  mirrors. Nothing else leaves your machine.
- **The desktop terminal and launcher run real commands** as your user, with
  the same power as any other terminal.
- PoseidonOS is an independent project. It isn't affiliated with or endorsed by
  KDE e.V., The Qt Company or the weather services it uses.
