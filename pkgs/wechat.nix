{ pkgs, fetchurl }:
pkgs.callPackage (pkgs.path + "/pkgs/by-name/we/wechat/linux.nix") {
  pname = "wechat";
  version = "4.1.13.26";
  src = fetchurl {
    url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
    hash = "sha256-RSYYC8qYASh5FZmvEi/0eVACpXFaUQ9qZUgOK+aHQkQ=";
  };
  meta = pkgs.wechat.meta;
}
