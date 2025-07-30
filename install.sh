#!/usr/bin/env bash
set -e

echo "🚀 Starting JoeKube Cloud Edition Setup..."

# --- 1. Initial Prompts ---
read -p "Enter new admin username: " NEWUSER

read -p "Disable root SSH login? (y/n): " DISABLEROOT

read -s -p "Enter VNC password: " VNCPASS
echo
read -s -p "Confirm VNC password: " VNCPASS2
echo
if [ "$VNCPASS" != "$VNCPASS2" ]; then
    echo "❌ Passwords do not match. Exiting."
    exit 1
fi

echo "✅ Inputs collected. Proceeding with setup..."

# --- 2. Create Admin User ---
adduser $NEWUSER
usermod -aG sudo $NEWUSER

# Copy SSH keys from root if they exist
if [ -d /root/.ssh ]; then
    mkdir -p /home/$NEWUSER/.ssh
    cp -r /root/.ssh/* /home/$NEWUSER/.ssh/
    chown -R $NEWUSER:$NEWUSER /home/$NEWUSER/.ssh
    chmod 700 /home/$NEWUSER/.ssh
    chmod 600 /home/$NEWUSER/.ssh/authorized_keys
fi

# Disable root login if selected
if [ "$DISABLEROOT" = "y" ]; then
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    systemctl restart sshd
    echo "✅ Root SSH login disabled."
fi

# Prepare VNC password for new user
mkdir -p /home/$NEWUSER/.vnc
echo -e "${VNCPASS}\n${VNCPASS}" | vncpasswd -f > /home/$NEWUSER/.vnc/passwd
chown -R $NEWUSER:$NEWUSER /home/$NEWUSER/.vnc
chmod 600 /home/$NEWUSER/.vnc/passwd

# --- 3. Switch to new user for desktop + apps install ---
sudo -u $NEWUSER bash <<'EOF_USER'

echo "🔄 Running desktop & apps install as $USER..."

# --- System Update ---
sudo apt update && sudo apt upgrade -y

# --- Detect RAM for Desktop Choice ---
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
echo "💾 Detected RAM: $TOTAL_RAM_MB MB"

if [ $TOTAL_RAM_MB -ge 2000 ]; then
    DESKTOP_ENV="GNOME"
    echo "🖥 Installing Ubuntu Desktop (GNOME)..."
    sudo apt install ubuntu-desktop gdm3 -y
else
    DESKTOP_ENV="XFCE"
    echo "🖥 Installing XFCE Desktop..."
    sudo apt install xfce4 xfce4-goodies -y
fi

# --- Install TigerVNC ---
if ! command -v vncserver &>/dev/null; then
    echo "🖥 Installing TigerVNC..."
    sudo apt install tigervnc-standalone-server -y
fi

# --- Configure xstartup for Desktop Type ---
if [ "$DESKTOP_ENV" = "GNOME" ]; then
    cat << 'EOGNOME' > ~/.vnc/xstartup
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec gnome-session --session=ubuntu &
EOGNOME
else
    cat << 'EOXFCE' > ~/.vnc/xstartup
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
EOXFCE
fi
chmod +x ~/.vnc/xstartup

# --- Theme & Appearance ---
echo "🎨 Installing Nordic + Papirus-Dark + Fira Code..."
sudo apt install -y gtk2-engines-murrine gtk2-engines-pixbuf fonts-firacode papirus-icon-theme git
if [ ! -d "/usr/share/themes/Nordic" ]; then
    sudo git clone https://github.com/EliverLara/Nordic /usr/share/themes/Nordic
fi

if [ "$DESKTOP_ENV" = "GNOME" ]; then
    gsettings set org.gnome.desktop.interface gtk-theme "Nordic"
    gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
elif [ "$DESKTOP_ENV" = "XFCE" ]; then
    xfconf-query -c xsettings -p /Net/ThemeName -s "Nordic"
    xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark"
fi

# --- Apps ---
echo "🛠 Installing Apps..."
if ! command -v desktopeditors &>/dev/null; then
    wget -qO /tmp/onlyoffice.deb https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_amd64.deb
    sudo apt install -y /tmp/onlyoffice.deb && rm /tmp/onlyoffice.deb
fi

if ! command -v google-chrome &>/dev/null; then
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
    sudo apt update
    if sudo apt install -y google-chrome-stable; then
        echo "✅ Chrome installed."
    else
        echo "⚠️ Chrome failed, installing Chromium..."
        sudo apt install -y chromium-browser
    fi
fi

if ! command -v wg &>/dev/null; then
    sudo apt install -y wireguard
fi

# --- VNC Service ---
SERVICE_FILE="/etc/systemd/system/tigervnc@.service"
if [ ! -f "$SERVICE_FILE" ]; then
    sudo tee "$SERVICE_FILE" > /dev/null <<EOVNCSVC
[Unit]
Description=Start TigerVNC server at startup for %i
After=network.target

[Service]
Type=forking
User=%i
PAMName=login
PIDFile=/home/%i/.vnc/%H:1.pid
ExecStartPre=-/usr/bin/vncserver -kill :1 > /dev/null 2>&1
ExecStart=/usr/bin/vncserver :1 -geometry 1920x1080 -depth 24
ExecStop=/usr/bin/vncserver -kill :1

[Install]
WantedBy=multi-user.target
EOVNCSVC
    sudo systemctl daemon-reload
    sudo systemctl enable tigervnc@$USER.service
    sudo systemctl start tigervnc@$USER.service
fi

EOF_USER

# --- Firewall ---
sudo apt install -y ufw
sudo ufw allow 5901/tcp
sudo ufw reload

# --- Final Output ---
IP=$(hostname -I | awk '{print $1}')
echo "✅ JoeKube Cloud Edition setup complete!"
echo "👉 Connect with Jump Desktop: ${IP}:5901 (User: $NEWUSER)"
read -p "Reboot now? (y/n): " REBOOT
if [ "$REBOOT" = "y" ]; then
    sudo reboot
fi
