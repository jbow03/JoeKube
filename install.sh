#!/usr/bin/env bash
set -e

echo "🚀 Starting JoeKube Lean (Ubuntu 25.04 Final – x11vnc Edition)..."

# --- 1. System Update & Upgrade ---
echo "📦 Updating system..."
sudo apt update && sudo apt upgrade -y

# --- 2. Core Tools ---
echo "🛠 Installing core utilities..."
sudo apt install -y \
  curl wget git unzip zip build-essential software-properties-common \
  gnome-tweaks gnome-shell-extensions gnome-shell-extension-manager \
  fonts-firacode dconf-cli

# --- 3. Appearance & UI ---
echo "🎨 Installing Nordic theme..."

safe_clone() {
    local repo_url=$1
    local dest_dir=$2
    if [ -d "$dest_dir" ]; then
        echo "⚠️ $dest_dir exists. Removing..."
        rm -rf "$dest_dir" || mv "$dest_dir" "${dest_dir}-backup-$(date +%s)"
    fi
    git clone "$repo_url" "$dest_dir"
}

safe_clone "https://github.com/EliverLara/Nordic.git" "/tmp/Nordic"

mkdir -p ~/.themes
cp -rf /tmp/Nordic ~/.themes/Nordic

# --- 4. Productivity Tools (OnlyOffice) ---
echo "📝 Installing OnlyOffice Desktop..."
if ! command -v desktopeditors &>/dev/null; then
    wget -qO /tmp/onlyoffice.deb https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_amd64.deb
    sudo apt install -y /tmp/onlyoffice.deb && rm /tmp/onlyoffice.deb
else
    echo "ℹ️ OnlyOffice already installed. Skipping."
fi

# --- 5. GNOME Customization ---
echo "🎨 Applying GNOME settings..."

gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
gsettings set org.gnome.desktop.interface gtk-theme "Nordic" || true
gsettings set org.gnome.shell.extensions.user-theme name "Nordic" || true

# Ubuntu Dock settings (auto-detect schema)
echo "⚙️ Configuring Dock..."
if gsettings list-schemas | grep -q "org.gnome.shell.extensions.dash-to-dock"; then
    echo "✔ Found Dash-to-Dock schema"
    SCHEMA="org.gnome.shell.extensions.dash-to-dock"
elif gsettings list-schemas | grep -q "org.gnome.shell.extensions.dash-to-dock-Ubuntu"; then
    echo "✔ Found Ubuntu Dock schema"
    SCHEMA="org.gnome.shell.extensions.dash-to-dock-Ubuntu"
else
    echo "⚠️ No Dock schema found. Skipping Dock customization."
    SCHEMA=""
fi

if [ -n "$SCHEMA" ]; then
    gsettings set $SCHEMA dock-position 'BOTTOM'
    gsettings set $SCHEMA dash-max-icon-size 48
    gsettings set $SCHEMA extend-height false
    gsettings set org.gnome.shell favorite-apps "[
      'firefox.desktop',
      'onlyoffice-desktopeditors.desktop',
      'org.gnome.Nautilus.desktop',
      'org.gnome.Terminal.desktop'
    ]"
fi

# Wallpaper
mkdir -p ~/Pictures/Wallpapers
if [ ! -f ~/Pictures/Wallpapers/joekube-dark.jpg ]; then
    wget -qO ~/Pictures/Wallpapers/joekube-dark.jpg https://i.imgur.com/Hz5uPzv.jpg
fi
gsettings set org.gnome.desktop.background picture-uri "file://$HOME/Pictures/Wallpapers/joekube-dark.jpg" || true
gsettings set org.gnome.desktop.background picture-options 'zoom' || true

# --- 6. VNC Setup (x11vnc - simple, always on) ---
echo "🖥 Configuring x11vnc (always on)..."
sudo apt install -y x11vnc

mkdir -p ~/.vnc
if [ ! -f ~/.vnc/passwd ]; then
    echo "ChangeMeVNC" | x11vnc -storepasswd stdin ~/.vnc/passwd
else
    echo "ℹ️ x11vnc password already set. Skipping."
fi

SERVICE_FILE="/etc/systemd/system/x11vnc.service"
if [ ! -f "$SERVICE_FILE" ]; then
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Start x11vnc at startup
After=display-manager.service

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -auth guess -forever -loop -noxdamage -repeat -rfbauth /home/${USER}/.vnc/passwd -rfbport 5900 -shared -display :0
User=${USER}
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/${USER}/.Xauthority

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable x11vnc.service
    sudo systemctl start x11vnc.service
else
    echo "ℹ️ x11vnc service already exists. Restarting..."
    sudo systemctl restart x11vnc.service
fi

# --- 7. Aliases ---
echo "📁 Adding JoeKube aliases..."
if ! grep -q "alias ll=" ~/.bashrc; then
cat << 'EOF' >> ~/.bashrc

# JoeKube Aliases
alias ll='ls -lh'
alias la='ls -lha'
alias update='sudo apt update && sudo apt upgrade -y'

EOF
else
    echo "ℹ️ Aliases already exist. Skipping."
fi

echo "✅ JoeKube Lean (Ubuntu 25.04 Final – x11vnc Edition) install complete! Reboot to enjoy your configured environment."
