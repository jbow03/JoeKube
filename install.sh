#!/usr/bin/env bash

set -e

echo "🚀 Starting JoeKube bootstrap (Lean Edition)..."

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
git clone https://github.com/EliverLara/Nordic.git /tmp/Nordic
mkdir -p ~/.themes && cp -r /tmp/Nordic ~/.themes/
gnome-extensions enable dash-to-dock@micxgx.gmail.com || true

# --- 4. Productivity Tools (OnlyOffice) ---
echo "📝 Installing OnlyOffice Desktop..."
wget -qO onlyoffice.deb https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_amd64.deb
sudo apt install -y ./onlyoffice.deb && rm onlyoffice.deb

# --- 5. GNOME Customization ---
echo "🎨 Applying GNOME settings..."

# Ensure Dash to Dock exists
sudo apt install -y gnome-shell-extension-dash-to-dock
gnome-extensions enable dash-to-dock@micxgx.gmail.com || true
killall -3 gnome-shell || true

# Dark theme
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme "Nordic"
gsettings set org.gnome.shell.extensions.user-theme name "Nordic"

# Dock settings
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 48
gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false

# Dock favorites
gsettings set org.gnome.shell favorite-apps "[
  'firefox.desktop',
  'onlyoffice-desktopeditors.desktop',
  'org.gnome.Nautilus.desktop',
  'org.gnome.Terminal.desktop'
]"

# Wallpaper
mkdir -p ~/Pictures/Wallpapers
wget -qO ~/Pictures/Wallpapers/joekube-dark.jpg https://i.imgur.com/Hz5uPzv.jpg
gsettings set org.gnome.desktop.background picture-uri "file://$HOME/Pictures/Wallpapers/joekube-dark.jpg"
gsettings set org.gnome.desktop.background picture-options 'zoom'

# --- 6. VNC Setup ---
echo "🖥 Configuring VNC (always on)..."
sudo apt install -y tigervnc-standalone-server tigervnc-common

# VNC password
mkdir -p ~/.vnc
(echo "ChangeMeVNC"; echo "ChangeMeVNC") | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# GNOME session for VNC
cat << 'EOF' > ~/.vnc/xstartup
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec /etc/X11/xinit/xinitrc
EOF
chmod +x ~/.vnc/xstartup

# Systemd service for VNC
sudo tee /etc/systemd/system/vncserver@.service > /dev/null <<EOF
[Unit]
Description=Start TigerVNC server at startup for %i
After=syslog.target network.target

[Service]
Type=forking
User=%i
PAMName=login
PIDFile=/home/%i/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver :%i -geometry 1920x1080 -depth 24
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable vncserver@1.service
sudo systemctl start vncserver@1.service

# --- 7. Aliases ---
echo "📁 Adding JoeKube aliases..."
cat << 'EOF' >> ~/.bashrc

# Aliases
alias ll='ls -lh'
alias la='ls -lha'
alias update='sudo apt update && sudo apt upgrade -y'

EOF

echo "✅ JoeKube Lean install complete! Reboot to enjoy your configured environment."
