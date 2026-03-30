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
}
