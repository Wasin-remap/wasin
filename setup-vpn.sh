#!/bin/bash

# -----------------------
# VPN + Web Installer
# By Wasin (Updated)
# -----------------------

# ========== CONFIG ==========
VPN_PSK="vpnYAMAHA123"
VPN_USERS=(
  "YAMAHA:212224"
  "HONDA:12345678"
  "MT15:99999999"
)
VPN_SUBNET="192.168.100"
WEB_HTML="Hello from your VPN server!"
# ============================

echo "🛠 ติดตั้ง VPN + Web Server..."

# อัปเดตระบบ
apt update -y && apt upgrade -y

# ติดตั้งแพ็กเกจ
apt install -y strongswan xl2tpd ppp ufw nginx curl dos2unix

# สร้าง ipsec.conf
cat > /etc/ipsec.conf <<EOF
config setup
  uniqueids=never
conn l2tp-psk
  keyexchange=ikev1
  authby=secret
  type=transport
  left=%defaultroute
  leftprotoport=17/1701
  right=%any
  rightprotoport=17/%any
  auto=add
  ike=aes256-sha1-modp1024!
  esp=aes256-sha1!
EOF

# สร้าง PSK
echo "%any  %any  : PSK \"$VPN_PSK\"" > /etc/ipsec.secrets

# ตั้งค่า xl2tpd.conf
cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
port = 1701

[lns default]
ip range = $VPN_SUBNET.10-$VPN_SUBNET.20
local ip = $VPN_SUBNET.1
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

# สร้าง options.xl2tpd
cat > /etc/ppp/options.xl2tpd <<EOF
require-mschap-v2
ms-dns 8.8.8.8
asyncmap 0
auth
crtscts
lock
hide-password
modem
mtu 1410
mru 1410
debug
name l2tpd
proxyarp
lcp-echo-interval 30
lcp-echo-failure 4
EOF

# สร้างไฟล์ user/pass
echo "" > /etc/ppp/chap-secrets
for USER_PAIR in "${VPN_USERS[@]}"; do
    IFS=":" read -r USER PASS <<< "$USER_PAIR"
    echo "$USER    l2tpd    $PASS    *" >> /etc/ppp/chap-secrets
done

# เปิด IP Forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# อนุญาต subnet VPN
ufw allow from $VPN_SUBNET.0/24

# เปิด firewall
ufw allow OpenSSH
ufw allow 500,4500,1701/udp
ufw allow http
ufw --force enable

# สร้างหน้าเว็บ
echo "<h1>$WEB_HTML</h1>" > /var/www/html/index.html
systemctl restart nginx

# รีสตาร์ท VPN service
systemctl restart strongswan
systemctl restart xl2tpd

# ตรวจสอบ IP
IP=$(curl -s ifconfig.me)

echo ""
echo "✅ ติดตั้งเรียบร้อยแล้ว!"
echo "🌐 Public IP: $IP"
echo "🔐 VPN PSK: $VPN_PSK"
for USER_PAIR in "${VPN_USERS[@]}"; do
    IFS=":" read -r USER PASS <<< "$USER_PAIR"
    echo "👤 User: $USER | Password: $PASS"
done
echo "📡 Subnet: $VPN_SUBNET.0/24"
echo "🌍 Web: http://$IP"
echo "📌 VPN Type: L2TP/IPSec with pre-shared key"
