# .dotfiles — niri + quickshell, Breeze Dark

Конфигурация рабочего стола: Wayland-композитор **niri**,
собственная панель на **quickshell**, терминал **foot**, лаунчер **fuzzel**, уведомления **mako** —
всё выдержано в палитре KDE Breeze Dark (`#232629` / `#31363b` / акцент `#3daee9`).

Горячие клавиши — в стиле sway (Mod = Super), раскладки `us,ru` переключаются Caps Lock.

## Структура

```
.dotfiles/
├── install.sh              # установка: симлинки в ~/.config
├── niri/                   # конфиг композитора (gaps, blur, скругления, спавн трёх процессов)
├── quickshell/             # панель + шторка быстрых настроек (GNOME-style), QML
├── foot/foot.ini           # терминал: Breeze-цвета, полупрозрачный фон (alpha 0.9)
├── fuzzel/fuzzel.ini       # лаунчер: Breeze-палитра, радиус 8, иконки Breeze-Dark
├── mako/config             # уведомления: стили urgent/critical, grouped by app-name
├── waybar/                 # ЛЕГАСИ: старая панель-прототип (использовалась до quickshell)
├── gtk-3.0/settings.ini    # GTK3: тема Breeze-Dark, иконки breeze-dark, шрифт Noto Sans 11
├── gtk-4.0/settings.ini    # GTK4: то же
├── qt6ct/                  # Qt: стиль Breeze, палитра BreezeDark, шрифт Noto Sans/Mono
├── xsettingsd/xsettingsd.conf  # транслирует тему в X11/GTK-приложения через GDK_BACKEND=x11
├── environment.d/90-breeze.conf  # QT_QPA_PLATFORMTHEME=qt6ct для всего пользовательского входа
├── cava/                   # аудиовизуализатор в терминале (+ шейдеры)
├── zsh/zshrc               # oh-my-zsh: agnoster, плагины git/syntax-highlighting/autosuggestions
├── scripts/
│   ├── session-menu        # dmenu-меню сессии (Logout/Suspend/Reboot/Shutdown) через fuzzel
│   └── wallpaper           # wall [имя] — установка (случайных) тёмных обоев через swaybg
└── wallpapers/dark-forest.jpg  # обои по умолчанию
```

## Используемый софт (Debian 13 trixie)

| Софт | Назначение | Пакет |
|---|---|---|
| [niri](https://github.com/YaLTeR/niri) | Wayland-композитор, scrollable-tiling | `niri` |
| [quickshell](https://quickshell.outfoxxed.me) | Панель + шторка QuickMenu/трей/медиа на QML (Qt 6.8+) | бинарник в `~/.local/bin` (см. ниже) |
| [foot](https://codeberg.org/dnkl/foot) | Wayland-терминал | `foot` |
| [fuzzel](https://codeberg.org/dnkl/fuzzel) | Лаунчер приложений + dmenu | `fuzzel` |
| [mako](https://github.com/emersion/mako) | Демон уведомлений | `mako-notifier` |
| Waybar | Старая панель (легаси, не запускается по умолчанию) | нет в системе |
| [swaybg](https://github.com/emersion/swaybg) | Обои (запускается из `niri/config.kdl`) | `swaybg` |
| [xsettingsd](https://github.com/joshuan/xsettingsd) | XSettings для x11-приложений | `xsettingsd` |
| [qt6ct](https://github.com/trialuser02/qt6ct) | Тема Qt: Breeze, палитра BreezeDark, шрифты | `qt6ct` |
| Breeze | GTK-тема, иконки, курсоры | `breeze-gtk-theme` `breeze-icon-theme` `breeze-cursor-theme` `breeze` |
| [cava](https://github.com/karlstav/cava) | Аудиовизуализатор в терминале | `cava` |
| zsh + oh-my-zsh | Оболочка: тема agnoster | `zsh`, клоны в `oh-my-zsh/custom/plugins` |
| zsh-autosuggestions / zsh-syntax-highlighting | Подсказки/подсветка команд | клоны в `~/.oh-my-zsh/custom/plugins` |
| [grim](https://github.com/emersion/grim) + [slurp](https://github.com/emersion/slurp) | Скриншоты области | `grim` `slurp` |
| wl-clipboard | Обмен через `wl-copy`/`wl-paste` | `wl-clipboard` |
| playerctl | Управление медиа (Mpris) | `playerctl` |
| brightnessctl | Яркость экрана | `brightnessctl` |
| PipeWire + WirePlumber | Звук (wpctl для громкости в хоткеях) | `pipewire` `pipewire-pulse` `pipewire-alsa` `wireplumber` |
| polkit-kde-agent | Аутентификация с Breeze-диалогом | `polkit-kde-agent-1` |
| xdg-desktop-portal-gnome / -gtk | Скринкасты/файл-пикеры | `xdg-desktop-portal-gnome` `xdg-desktop-portal-gtk` |
| Noto Sans / Sans Mono / Emoji | Основные и моно-шрифты | `fonts-noto-core` `fonts-noto-mono` `fonts-noto-color-emoji` |
| Font Awesome 6 | Иконки панели (глифы \uf028 и т.д.) | `fonts-font-awesome` |
| sway | Нет (клавиши sway — стилизация) | — |

## Что не входит в репозиторий

- **quickshell** — бинарник держится в `~/.local/bin/quickshell` (копия официального релиза).
  В Debian нет пакета, ставьте [официальный релиз](https://github.com/quickshell-mirror/quickshell/releases).
- **oh-my-zsh** и плагины — ставятся клонами, в репозиторий не включены:
  ```bash
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  git clone https://github.com/zsh-users/zsh-autosuggestions        ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting   ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
  ```
- Системные темы Breeze ставятся из apt (указаны в таблице).

## Установка

```bash
git clone https://github.com/<user>/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

`install.sh` создаёт симлинки в `~/.config` и `~/.zshrc` (существующие файлы бэкапит как `*.bak.<ts>`),
копирует обои по умолчанию в `~/Pictures/Wallpapers/Dark/`.

Затем перезайдите в сессию niri или перезапустите панель: `pkill -f quickshell`.

## Полезное

- **Обои**: `wall` — случайные тёмные, `wall foggy` — по подстроке, `wall --list` — список.
- **Сессия**: power-кнопка в панели открывает QuickMenu; либо `fuzzel --dmenu`-скрипт `session-menu`.
- **Скриншоты**: `Print` — экран, `Alt+Print` — окно, `Mod+Print` — область в буфер, `Mod+Shift+Print` — область в файл.
- **Обзор**: `Mod+O` — обзор рабочих столов.
- **Редактор конфига**: niri перечитывает config на сохранении (`Mod+Shift+C` — принудительно).
- **Быстрая справка**: `Mod+Shift+/` — оверлей всех хоткеев.
