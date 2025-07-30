#!/usr/bin/env bash
set -e

echo "🚀 Starting JoeKube Lean (Ubuntu 25.04 Optimized)..."

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

# Safe clone function
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

# Dark theme
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
gsettings set org.gnome.desktop.interface gtk-theme "Nordic" || true
gsettings set org.gnome.shell.extensions.user-theme name "Nordic" || true

# Ubuntu Dock settings for 25.04
echo "⚙️ Configuring Ubuntu Dock..."
if gsettings list-schemas | grep -q "org.gnome.shell.extensions.dash-to-dock-Ubuntu"; then
    gsettings set org.gnome.shell.extensions.dash-to-dock-Ubuntu dock-position 'BOTTOM'
    gsettings set org.gnome.shell.extensions.dash-to-dock-Ubuntu dash-max-icon-size 48
    gsettings set org.gnome.shell.extensions.dash-to-dock-Ubuntu extend-height false
    gsettings set org.gnome.shell favorite-apps "[
      'firefox.desktop',
      'onlyoffice-desktopeditors.desktop',
      'org.gnome.Nautilus.desktop',
      'org.gnome.Terminal.desktop'
    ]"
else
    echo "⚠️ Ubuntu Dock schema not found. Skipping Dock customization."
fi

# Wallpaper
mkdir -p ~/Pictures/Wallpapers
if [ ! -f ~/Pictures/Wallpapers/joekube-dark.jpg ]; then
    wget -qO ~/Pictures/Wallpapers/joekube-dark.jpg https://i.imgur.com/Hz5uPzv.jpg
fi
gsettings set org.gnome.desktop.background picture-uri "file://$HOME/Pictures/Wallpapers/joekube-dark.jpg" || true
gsettings set org.gnome.desktop.background picture-options 'zoom' || true

# --- 6. VNC Setup ---
echo "🖥 Configuring VNC (always on)..."
sudo apt install -y tigervnc-standalone-server tigervnc-common

mkdir -p ~/.vnc
if [ ! -f ~/.vnc/passwd ]; then
    (echo "ChangeMeVNC"; echo "ChangeMeVNC") | vncpasswd -f > ~/.vnc/passwd
    chmod 600 ~/.vnc/passwd
else
    echo "ℹ️ VNC password already set. Skipping."
fi

cat << 'EOF' > ~/.vnc/xstartup
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec /etc/X11/xinit/xinitrc
EOF
chmod +x ~/.vnc/xstartup

if [ ! -f /etc/systemd/system/vncserver@.service ]; then
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
else
    echo "ℹ️ VNC service already configured. Restarting..."
    sudo systemctl restart vncserver@1.service
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

echo "✅ JoeKube Lean (Ubuntu 25.04 Optimized) install complete! Reboot to enjoy your configured environment."

