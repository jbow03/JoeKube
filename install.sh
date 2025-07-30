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

EOF

echo "✅ JoeKube installation complete! Restart or log out to apply all changes."
