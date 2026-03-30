{ pkgs, ... }:

{
  name = "zun-server-env";

  packages = with pkgs; [
    docker
    docker-compose
    tailscale
    nodejs_20
    curl
    git
    bash
    openssh
    findutils
    coreutils
    gnused
    gawk
    procps
    vim
    htop
    netcat
    jq
    wget
    unzip
    python3
  ];

  services.docker = {
    enable = true;
    autoStart = true;
  };

  env = {
    DOCKER_HOST = "unix:///var/run/docker.sock";
  };

  scripts = {
    cleanup-host = ''
      if [ ! -f "$HOME/.cleanup_done" ]; then
        rm -rf "$HOME/.gradle" "$HOME/.emu" 2>/dev/null || true
        find "$HOME" -mindepth 1 -maxdepth 1 ! -name 'idx-ubuntu22-gui' ! -name '.*' -exec rm -rf {} + 2>/dev/null || true
        touch "$HOME/.cleanup_done"
        echo "✅ Dọn dẹp host hoàn tất."
      else
        echo "⏭️ Host đã được dọn trước đó."
      fi
    '';

    remove-container = ''
      docker rm -f Zun-Server 2>/dev/null || true
      echo "✅ Container đã xóa, giải phóng dung lượng."
    '';

    create-container = ''
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

    install-tailscale = ''
      docker exec Zun-Server bash -c '
        apt update -qq && apt install -y -qq curl &&
        curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null &&
        curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list &&
        apt update -qq && apt install -y -qq tailscale
      '
      echo "✅ Tailscale đã cài trong container."
    '';

    start-tailscaled = ''
      docker exec Zun-Server bash -c '
        mkdir -p /var/lib/tailscale
        nohup tailscaled --state=/var/lib/tailscale/tailscaled.state > /var/log/tailscaled.log 2>&1 &
        sleep 2
      '
      echo "✅ tailscaled đã khởi động."
    '';

    tailscale-up = ''
      docker exec Zun-Server tailscale up --authkey=tskey-auth-hkLFsqw5jzS11CNTRL-HLGErV9ZdVP4bV1kuJfHVP6B1JsdC8t --hostname=Zun-Server --accept-routes
      docker exec Zun-Server tailscale status
      echo "✅ Tailscale đã kết nối."
    '';

    tailscale-log = ''
      docker exec Zun-Server cat /var/log/tailscaled.log
    '';

    install-ssh = ''
      docker exec Zun-Server bash -c '
        apt update && apt install -y openssh-server &&
        mkdir -p /var/run/sshd &&
        echo "PermitRootLogin yes" >> /etc/ssh/sshd_config &&
        echo "root:123456" | chpasswd &&
        /usr/sbin/sshd
      '
      echo "✅ SSH server đã chạy trên cổng 22."
    '';

    install-chrome = ''
      docker exec Zun-Server bash -c '
        apt update && apt install -y wget gnupg &&
        wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - &&
        echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list &&
        apt update && apt install -y google-chrome-stable
      '
      echo "✅ Google Chrome đã cài sẵn."
    '';

    setup-desktop = ''
      # Tạo shortcut Chrome trên desktop (nếu có thư mục Desktop)
      docker exec Zun-Server bash -c '
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
      echo "✅ Desktop đã sẵn sàng (truy cập qua http://localhost:8080, pass: 123456)."
    '';

    enter = "docker exec -it Zun-Server bash";

    full-setup = ''
      echo "===== BẮT ĐẦU SETUP ====="
      cleanup-host
      remove-container
      create-container
      install-tailscale
      start-tailscaled
      tailscale-up
      install-ssh
      install-chrome
      setup-desktop
      echo "===== SETUP HOÀN TẤT ====="
      echo "🔗 Truy cập desktop: http://localhost:8080 (pass: 123456)"
      echo "🔌 SSH: ssh root@localhost -p 22 (pass: 123456)"
    '';

    reset-container = ''
      remove-container
      create-container
      start-tailscaled
      install-ssh
      install-chrome
      setup-desktop
      echo "✅ Container reset xong (Tailscale sẽ tự kết nối lại nếu đã login)."
    '';

    status = ''
      docker ps -f name=Zun-Server
      echo ""
      docker exec Zun-Server tailscale status 2>/dev/null || echo "Tailscale chưa chạy"
      echo ""
      docker exec Zun-Server ps aux | grep -E "sshd|chrome" || true
    '';
  };
}
