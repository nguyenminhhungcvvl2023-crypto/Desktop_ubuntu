{ pkgs, ... }:
{
  channel = "stable-24.11";

  packages = [
    pkgs.bash
    pkgs.coreutils
    pkgs.findutils
    pkgs.gnugrep
  ];

  scripts = {
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
  };
}
