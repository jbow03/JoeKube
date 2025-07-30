#!/usr/bin/env bash

set -e

echo "🚀 Starting JoeKube bootstrap..."

# --- 1. Update & Upgrade ---
echo "📦 Updating system..."
sudo apt update && sudo apt upgrade -y

# --- 2. Core System Tools ---
echo "🛠 Installing core tools..."
sudo apt install -y \
  curl wget git unzip zip build-essential software-properties-common \
  gnome-tweaks gnome-shell-extensions gnome-shell-extension-manager \
  fonts-firacode

# --- 3. Appearance & UI ---
echo "🎨 Setting up GNOME theme & extensions..."
sudo apt install -y \
  dconf-cli
# Nord Theme example (change to Catppuccin if you prefer)
git clone https://github.com/EliverLara/Nordic.git /tmp/Nordic
mkdir -p ~/.themes && cp -r /tmp/Nordic ~/.themes/

# Dash to Dock
gnome-extensions enable dash-to-dock@micxgx.gmail.com || true

# --- 4. Terminal (Zsh + Oh My Zsh) ---
echo "💻 Installing Zsh & Oh My Zsh..."
sudo apt install -y zsh fzf ripgrep bat
chsh -s $(which zsh)

echo "Installing Oh My Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Powerlevel10k
echo "Installing Powerlevel10k..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
sed -i 's/ZSH_THEME=".*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc

# Plugins
echo "Adding Zsh plugins..."
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

# --- 5. Dev & Automation Tools ---
echo "⚙️ Installing dev tools..."
sudo apt install -y python3-pip python3-venv nodejs npm docker.io docker-compose make

# Optional: Add yourself to Docker group
sudo usermod -aG docker $USER

# --- 6. Productivity & AI ---
echo "🧠 Installing productivity tools..."
# Obsidian
wget -qO obsidian.deb https://github.com/obsidianmd/obsidian-releases/releases/latest/download/obsidian_amd64.deb
sudo apt install -y ./obsidian.deb && rm obsidian.deb

# VS Code
wget -qO vscode.deb "https://update.code.visualstudio.com/latest/linux-deb-x64/stable"
sudo apt install -y ./vscode.deb && rm vscode.deb

# Ulauncher
sudo add-apt-repository ppa:agornostal/ulauncher -y
sudo apt update && sudo apt install -y ulauncher

# Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# --- 7. Dotfiles ---
echo "📁 Adding JoeKube dotfiles..."
cat << 'EOF' >> ~/.zshrc

# Aliases
alias ll='ls -lh'
alias la='ls -lha'
alias gs='git status'
alias update='sudo apt update && sudo apt upgrade -y'

# Path additions
export PATH=$PATH:$HOME/bin

# --- 9. GNOME Customization ---
echo "🎨 Applying GNOME customization..."

# Set dark theme
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Set Nordic theme for GTK and Shell
gsettings set org.gnome.desktop.interface gtk-theme "Nordic"
gsettings set org.gnome.shell.extensions.user-theme name "Nordic"

# Dock settings
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 48
gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false

# Dock favorites (adjust order as needed)
gsettings set org.gnome.shell favorite-apps "[
  'firefox.desktop',
  'code.desktop',
  'onlyoffice-desktopeditors.desktop',
  'org.gnome.Nautilus.desktop',
  'obsidian.desktop',
  'org.gnome.Terminal.desktop'
]"

# Wallpaper (simple dark image)
mkdir -p ~/Pictures/Wallpapers
wget -qO ~/Pictures/Wallpapers/joekube-dark.jpg https://i.imgur.com/Hz5uPzv.jpg
gsettings set org.gnome.desktop.background picture-uri "file://$HOME/Pictures/Wallpapers/joekube-dark.jpg"
gsettings set org.gnome.desktop.background picture-options 'zoom'

# Keyboard shortcuts
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "[
  '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/',
  '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/'
]"

gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Launch Terminal'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'gnome-terminal'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>t'

gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ name 'Launch Obsidian'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ command 'obsidian'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding '<Super>o'

# --- 10. VNC Setup ---
echo "🖥 Setting up VNC Server..."

# Install TigerVNC
sudo apt install -y tigervnc-standalone-server tigervnc-common

# Create VNC password
mkdir -p ~/.vnc
echo "Setting default VNC password..."
(echo "yourVNCpassword"; echo "yourVNCpassword") | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# Configure GNOME session for VNC
cat << 'EOF' > ~/.vnc/xstartup
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec /etc/X11/xinit/xinitrc
EOF
chmod +x ~/.vnc/xstartup

# Create systemd service (listen on all interfaces)
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

# Enable VNC for display :1
sudo systemctl daemon-reload
sudo systemctl enable vncserver@1.service
sudo systemctl start vncserver@1.service


EOF

echo "✅ JoeKube installation complete! Restart or log out to apply all changes."
