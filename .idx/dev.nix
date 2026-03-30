{ pkgs, ... }:

{
  name = "zun-treo-base";

  packages = with pkgs; [
    bash
    curl
    wget
    git
    screen
    xdotool
    wmctrl
    coreutils
    procps
    findutils
    docker-client
  ];

  scripts = {
    # Dọn dẹp môi trường host (xoá các thư mục .gradle, .emu và các thư mục không cần thiết)
    cleanup = ''
      if [ ! -f "$HOME/.cleanup_done" ]; then
        rm -rf "$HOME/.gradle/"* "$HOME/.emu/"* 2>/dev/null || true
        find "$HOME" -mindepth 1 -maxdepth 1 \
          ! -name 'idx-windows-gui' \
          ! -name '.cleanup_done' \
          ! -name '.*' \
          -exec rm -rf {} + 2>/dev/null || true
        touch "$HOME/.cleanup_done"
        echo "✅ Đã dọn dẹp host."
      else
        echo "⏭️ Đã dọn dẹp trước đó."
      fi
    '';

    # (Các script khác bạn có thể thêm vào, ví dụ setup-docker, setup-container, treo...)
    # Chú ý: không nên tự động chạy khi build, hãy để người dùng gọi thủ công.
  };
}
