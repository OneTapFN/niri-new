#!/usr/bin/env bash
# Установка дотфайлов niri + quickshell (Breeze Dark).
# Создаёт симлинки из ~/.config (и $HOME) на файлы в этом репозитории.
# Существующие файлы не удаляются — бэкапятся рядом с суффиксом .bak.

set -euo pipefail

DOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_BIN="${XDG_BIN_HOME:-$HOME/.local/bin}"

timestamp() { date +%Y%m%d-%H%M%S; }

# Заменяет dst симлинком на src. Оригинал сохраняется как dst.bak.<ts>.
link() {
	local src="$1" dst="$2"
	mkdir -p "$(dirname "$dst")"
	if [[ -L "$dst" ]]; then
		rm "$dst"
	elif [[ -e "$dst" ]]; then
		mv "$dst" "$dst.bak.$(timestamp)"
		echo "  бэкап: $dst.bak.$(timestamp)"
	fi
	ln -s "$src" "$dst"
	echo "  $dst -> $src"
}

echo "Установка из: $DOT_DIR"

# Каталоги конфигов — симлинками целиком
for app in niri quickshell foot fuzzel mako waybar qt6ct xsettingsd cava gtk-4.0 environment.d; do
	if [[ -d "$DOT_DIR/$app" ]]; then
		link "$DOT_DIR/$app" "$CONFIG_DIR/$app"
	fi
done

# GTK 3 — симлинк только на settings.ini (bookmarks остаётся на месте)
link "$DOT_DIR/gtk-3.0/settings.ini" "$CONFIG_DIR/gtk-3.0/settings.ini"

# Zsh
link "$DOT_DIR/zsh/zshrc" "$HOME/.zshrc"

# Скрипты в ~/bin на PATH
for s in session-menu wallpaper; do
	if [[ -f "$DOT_DIR/scripts/$s" ]]; then
		chmod +x "$DOT_DIR/scripts/$s"
		link "$DOT_DIR/scripts/$s" "$LOCAL_BIN/$s"
	fi
done

# Обои по умолчанию (не перезаписываем существующие)
if [[ -f "$DOT_DIR/wallpapers/dark-forest.jpg" ]]; then
	mkdir -p "$HOME/Pictures/Wallpapers/Dark"
	cp -n "$DOT_DIR/wallpapers/dark-forest.jpg" "$HOME/Pictures/Wallpapers/Dark/dark-forest.jpg" || true
fi

echo
echo "Готово. Пути по умолчанию:"
echo "  • обои ставятся в niri/config.kdl (spawn-at-startup swaybg ...)"
echo "  • вальпер поменять на лету: wall <имя>  (или просто wall — случайные тёмные)"
if command -v niri >/dev/null 2>&1 && niri msg >/dev/null 2>&1; then
	niri msg action load-config-file && echo "  • конфиг niri перечитан"
fi
echo "Если панель (quickshell) уже запущена — перезапустите её: pkill -f quickshell && ~/.local/bin/quickshell &"
