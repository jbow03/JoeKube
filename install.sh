#!/usr/bin/env bash
set -e

echo "🚀 Starting JoeKube Lean (Ubuntu 25.04 Final – VNC Username Fix)..."

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

# --- 6. VNC Setup (Correct username service) ---
echo "🖥 Configuring VNC (always on)..."
sudo apt install -y tigervnc-standalone-server tigervnc-common

mkdir -p ~/.vnc
if [ ! -f ~/.vnc/passwd ]; then
    (echo "ChangeMeVNC"; echo "ChangeMeVNC") | vncpasswd -f > ~/.vnc/passwd
    chmod 600 ~/.vnc/passwd
else
    echo "ℹ️ VNC password already set. Skipping."
fi

# GNOME-compliant VNC startup
cat << 'EOF' > ~/.vnc/xstartup
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec /usr/bin/gnome-session --session=ubuntu &
EOF
chmod +x ~/.vnc/xstartup

# Create systemd service for current username
SERVICE_NAME="vncserver@${USER}.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"
if [ ! -f "$SERVICE_FILE" ]; then
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Start TigerVNC server at startup for ${USER}
After=syslog.target network.target

[Service]
Type=forking
User=${USER}
PAMName=login
Environment=XDG_RUNTIME_DIR=/run/user/$(id -u)
PIDFile=/home/${USER}/.vnc/%H:1.pid
ExecStartPre=-/usr/bin/vncserver -kill :1 > /dev/null 2>&1
ExecStart=/usr/bin/vncserver :1 -geometry 1920x1080 -depth 24 -fg
ExecStop=/usr/bin/vncserver -kill :1

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable "${SERVICE_NAME}"
    sudo systemctl start "${SERVICE_NAME}"
else
    echo "ℹ️ VNC service for ${USER} already exists. Restarting..."
    sudo systemctl restart "${SERVICE_NAME}"
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

echo "✅ JoeKube Lean (Ubuntu 25.04 Final – VNC Username Fix) install complete! Reboot to enjoy your configured environment."
