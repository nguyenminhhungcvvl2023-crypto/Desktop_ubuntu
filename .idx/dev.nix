{ pkgs, ... }:

{
  name = "zun-treo";

  packages = with pkgs; [
    bash
    curl
    wget
    git
    screen
    xdotool
    wmctrl
    chromium
    docker-client
  ];

  scripts = {
    # ---------- Dọn dẹp host, giải phóng dung lượng ----------
    cleanup = ''
      echo "🧹 Dọn dẹp các file rác và container cũ..."
      docker rm -f Zun-Server 2>/dev/null || true
      rm -rf ~/.docker ~/.gradle ~/.cache ~/.npm ~/.local/share/containers 2>/dev/null || true
      echo "✅ Đã xóa container và các file tạm. Dung lượng đã được giải phóng."
    '';

    # ---------- Cài Docker nếu chưa có ----------
    setup-docker = ''
      if ! command -v docker &> /dev/null; then
        echo "📦 Cài Docker..."
        sudo apt update && sudo apt install -y docker.io
        sudo usermod -aG docker $USER
        echo "✅ Docker đã sẵn sàng. (Có thể cần đăng xuất lại hoặc chạy 'newgrp docker')"
      else
        echo "✅ Docker đã có."
      fi
    '';

    # ---------- Tạo container Zun-Server ----------
    setup-container = ''
      echo "🚀 Tạo container Zun-Server..."
      docker rm -f Zun-Server 2>/dev/null || true
      docker run -d --name Zun-Server \
        --restart always \
        --shm-size=2g \
        --cap-add=NONE \
        --device /dev/mem:/dev/mem \
        -p 8080:10000 -p 5900:5900 -p 22:22 \
        -e VNC_PASSWORD=123456 \
        thuanghaizhengzi1711/ubuntu-novnc-pulseaudio:22.04 \
        sleep infinity
      echo "✅ Container Zun-Server đã tạo."
    '';

    # ---------- Cài SSH, Tailscale, Chrome bên trong container ----------
    install-services = ''
      echo "🔧 Cài SSH, Tailscale, Chrome trong container..."
      docker exec Zun-Server bash -c '
        apt update -qq
        apt install -y -qq curl openssh-server wget gnupg

        # Tailscale
        curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
        curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
        apt update -qq
        apt install -y -qq tailscale

        # SSH
        mkdir -p /var/run/sshd
        echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
        echo "root:123456" | chpasswd
        /usr/sbin/sshd

        # Google Chrome
        wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
        echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list
        apt update -qq
        apt install -y -qq google-chrome-stable

        # Desktop shortcut
        mkdir -p /home/ubuntu/Desktop
        cat > /home/ubuntu/Desktop/chrome.desktop <<EOF
[Desktop Entry]
Name=Google Chrome
Exec=google-chrome-stable --no-sandbox
Icon=google-chrome
Type=Application
EOF
        chmod +x /home/ubuntu/Desktop/chrome.desktop
        chown -R ubuntu:ubuntu /home/ubuntu/Desktop 2>/dev/null || true
      '
      echo "✅ Dịch vụ đã cài."
    '';

    # ---------- Khởi động tailscaled và kết nối (yêu cầu nhập auth key) ----------
    start-tailscale = ''
      echo "🐧 Khởi động tailscaled..."
      docker exec Zun-Server bash -c '
        mkdir -p /var/lib/tailscale
        nohup tailscaled --state=/var/lib/tailscale/tailscaled.state > /var/log/tailscaled.log 2>&1 &
        sleep 2
      '
      echo "✅ tailscaled đã chạy."
      read -p "🔑 Nhập auth key Tailscale: " AUTH_KEY
      docker exec Zun-Server tailscale up --authkey=$AUTH_KEY --hostname=Zun-Server --accept-routes
      docker exec Zun-Server tailscale status
      echo "✅ Tailscale đã kết nối."
    '';

    # ---------- Tạo script treo IDX (tự động giữ phiên) ----------
    install-treo = ''
      cat > ~/auto_treo.sh << 'EOF'
#!/usr/bin/env bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== TREO IDX TỰ ĐỘNG ===${NC}"
echo -n "Nhập lựa chọn (1 để treo, 2 để thoát): "
read choice
if [ "$choice" != "1" ]; then
  echo "Thoát."
  exit 0
fi

echo -n "Xác nhận (gõ yes): "
read confirm
if [ "$confirm" != "yes" ]; then
  echo "Không xác nhận, thoát."
  exit 0
fi

echo -n "Dán link IDX vào đây: "
read idx_link

echo -e "${YELLOW}Đang mở trình duyệt với link: $idx_link${NC}"
if command -v chromium &> /dev/null; then
  chromium --new-window "$idx_link" &
elif command -v google-chrome &> /dev/null; then
  google-chrome --new-window "$idx_link" &
else
  xdg-open "$idx_link" &
fi

sleep 5

echo -e "${GREEN}Bắt đầu giữ phiên...${NC}"
screen -dmS keepalive bash -c '
while true; do
  echo "$(date) >>> KEEPALIVE <<<"
  df -h | head -5
  free -h
  uptime
  echo "---"
  sleep 300
done
'

echo -e "${GREEN}Đã khởi động keepalive (lệnh mỗi 5 phút).${NC}"
echo -n "Bạn có muốn tự động refresh trang mỗi 45 phút không? (y/n): "
read refresh_choice
if [[ "$refresh_choice" == "y" || "$refresh_choice" == "Y" ]]; then
  if command -v xdotool &> /dev/null && command -v wmctrl &> /dev/null; then
    nohup bash -c '
      while true; do
        sleep 2700
        WINDOW=$(wmctrl -l | grep -i "chromium\|google-chrome" | head -1 | awk "{print \$1}")
        if [ -n "$WINDOW" ]; then
          xdotool windowactivate "$WINDOW" key F5
          echo "$(date) -> Đã refresh trang"
        else
          echo "$(date) -> Không tìm thấy cửa sổ trình duyệt"
        fi
      done
    ' &> ~/auto_refresh.log &
    echo -e "${GREEN}Đã bật tự động refresh mỗi 45 phút.${NC}"
  else
    echo -e "${YELLOW}Thiếu xdotool hoặc wmctrl, không thể tự động refresh.${NC}"
  fi
fi

echo -e "${GREEN}=== TREO ĐÃ BẮT ĐẦU ==="
echo "Để dừng: screen -S keepalive -X quit && pkill -f 'sleep 2700'"
echo "Xem log keepalive: screen -r keepalive"
echo "Xem log refresh: cat ~/auto_refresh.log"
EOF
      chmod +x ~/auto_treo.sh
      echo "✅ Script ~/auto_treo.sh đã sẵn sàng."
    '';

    # ---------- Chạy toàn bộ quy trình (1 lệnh duy nhất) ----------
    full-setup = ''
      echo "===== BẮT ĐẦU SETUP ====="
      setup-docker
      setup-container
      install-services
      start-tailscale
      install-treo
      echo "===== SETUP HOÀN TẤT ====="
      echo "🔗 Truy cập desktop: http://localhost:8080 (pass: 123456)"
      echo "🔌 SSH: ssh root@localhost -p 22 (pass: 123456)"
      echo "📌 Để treo IDX, chạy: ~/auto_treo.sh"
    '';

    # ---------- Xóa container cũ và tạo lại (giải phóng dung lượng) ----------
    reset-container = ''
      echo "🔄 Xóa container cũ để giải phóng ~16GB..."
      docker rm -f Zun-Server 2>/dev/null || true
      echo "✅ Đã xóa. Tạo container mới..."
      setup-container
      install-services
      echo "✅ Container mới đã sẵn sàng."
    '';

    # ---------- Kiểm tra trạng thái ----------
    status = ''
      docker ps -f name=Zun-Server
      echo ""
      docker exec Zun-Server tailscale status 2>/dev/null || echo "Tailscale chưa chạy"
    '';

    # ---------- Mở shell vào container ----------
    enter = "docker exec -it Zun-Server bash";
  };
}
