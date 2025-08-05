#!/bin/bash
# setup-easyvpn.sh for Ubuntu 24.04
# VPN L2TP/IPSec + sample website
# No extra app needed on PC/mobile

# ==== CONFIG ====
VPN_USER="vpnuser"
VPN_PASS="212224"
VPN_PSK="vpnkey123"
VPN_NET="192.168.100"
WEB_HTML="<h1>🌐 Sample Website by Wasin</h1><p>VPN Ready for PC & Mobile</p>"
# =================

export DEBIAN_FRONTEND=noninteractive

echo "🔧 Installing packages..."
apt update && apt install -y strongswan xl2tpd ppp ufw nginx curl

# ============ VPN CONFIG ============

cat > /etc/ipsec.conf <<EOF
config setup
  uniqueids=no
conn l2tp-psk
  keyexchange=ikev1
  authby=secret
  type=transport
  left=%defaultroute
  leftprotoport=17/1701
  right=%any
  rightprotoport=17/%any
  auto=add
EOF

echo "%any  %any  : PSK \"$VPN_PSK\"" > /etc/ipsec.secrets

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
port = 1701

[lns default]
ip range = $VPN_NET.10-$VPN_NET.20
local ip = $VPN_NET.1
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

cat > /etc/ppp/options.xl2tpd <<EOF
ipcp-accept-local
ipcp-accept-remote
ms-dns 8.8.8.8
noccp
auth
crtscts
idle 1800
mtu 1410
mru 1410
lock
connect-delay 5000
EOF

echo "$VPN_USER l2tpd $VPN_PASS *" > /etc/ppp/chap-secrets

# Enable IP forward
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Firewall
ufw allow OpenSSH
ufw allow 500,4500,1701/udp
ufw allow http
ufw allow from $VPN_NET.0/24
ufw --force enable

# Start services
systemctl restart strongswan
systemctl restart xl2tpd

# ============ WEBSITE ============
echo "$WEB_HTML" > /var/www/html/index.html
systemctl restart nginx

# ============ DONE ============

IP=$(curl -s ifconfig.me)
echo ""
echo "✅ VPN & Website Ready!"
echo "🌐 Public IP: $IP"
echo "📡 VPN Type: L2TP/IPSec"
echo "👤 Username: $VPN_USER"
echo "🔑 Password: $VPN_PASS"
echo "🗝️  PSK: $VPN_PSK"
echo "🧭 Open website: http://$IP"
echo "📱 Connect VPN from Windows/iOS/macOS/Android → No app needed"
