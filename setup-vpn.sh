#!/bin/bash

# ========== CONFIG ==========
VPN_PSK="vpnYAMAHA123"
VPN_USER="YAMAHA"
VPN_PASS="212224"
VPN_NET="192.168.100"
WEB_HTML="Hello from your VPN server!"
# ============================

echo "🛠 ติดตั้ง VPN + Web Server บน Ubuntu..."

# อัปเดตระบบ
apt update -y && apt upgrade -y

# ติดตั้งแพ็คเกจหลัก
apt install -y strongswan xl2tpd ppp ufw nginx curl

# ตั้งค่า ipsec.conf
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

# ตั้งค่า PSK
echo "%any  %any  : PSK \"$VPN_PSK\"" > /etc/ipsec.secrets

# ตั้งค่า xl2tpd.conf
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
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

# ตั้งค่า options.xl2tpd
cat > /etc/ppp/options.xl2tpd <<EOF
require-mschap-v2
ms-dns 8.8.8.8
asyncmap 0
auth
crtscts
lock
modem
mtu 1410
mru 1410
debug
name l2tpd
proxyarp
lcp-echo-interval 30
lcp-echo-failure 4
EOF

# สร้าง chap-secrets (user/pass)
echo "$VPN_USER * $VPN_PASS *" > /etc/ppp/chap-secrets

# เปิด IP Forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# ปรับ firewall
ufw allow OpenSSH
ufw allow 500,4500,1701/udp
ufw allow http
ufw --force enable

# สร้างหน้าเว็บ
echo "<h1>$WEB_HTML</h1>" > /var/www/html/index.html
systemctl restart nginx

# เริ่มบริการ VPN
systemctl restart strongswan
systemctl restart xl2tpd

# ตรวจสอบ IP
IP=$(curl -s ifconfig.me)

echo ""
echo "✅ ติดตั้งเรียบร้อย!"
echo "🌐 Public IP: $IP"
echo "🔐 VPN Username: $VPN_USER"
echo "🔐 VPN Password: $VPN_PASS"
echo "🔐 VPN PSK: $VPN_PSK"
echo "📡 VPN Network: $VPN_NET.0/24"
echo "🌍 เปิดเบราว์เซอร์: http://$IP"
echo ""
echo "📌 เชื่อมต่อจาก Windows ด้วย L2TP/IPSec (Pre-shared Key)
