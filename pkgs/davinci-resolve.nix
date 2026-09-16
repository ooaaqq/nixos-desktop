{
  cacert,
  curl,
  jq,
  lib,
  pkgs,
  runCommandLocal,
  stdenv,
}:

let
  # Blackmagic replaced the archive served for 21.1 without changing the
  # versioned download entry; keep the current official archive hash fixed.
  source =
    runCommandLocal "davinci-resolve-src.zip"
      rec {
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-+3SB32EHpH9/0hM3h8CrO6f7V4ZAmxUFh3P8m6QDeO0=";

        impureEnvVars = lib.fetchers.proxyImpureEnvVars;
        nativeBuildInputs = [
          curl
          jq
        ];

        SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
        REFERID = "263d62f31cbb49e0868005059abcb0c9";
        DOWNLOADSURL = "https://www.blackmagicdesign.com/api/support/us/downloads.json";
        SITEURL = "https://www.blackmagicdesign.com/api/register/us/download";
        PRODUCT = "DaVinci Resolve";
        VERSION = pkgs.davinci-resolve.version;
        USERAGENT = builtins.concatStringsSep " " [
          "User-Agent: Mozilla/5.0 (X11; Linux x86_64)"
          "AppleWebKit/537.36 (KHTML, like Gecko)"
          "Chrome/77.0.3865.75"
          "Safari/537.36"
        ];
        REQJSON = builtins.toJSON {
          firstname = "NixOS";
          lastname = "Linux";
          email = "someone@nixos.org";
          phone = "+31 71 452 5670";
          country = "nl";
          street = "-";
          state = "Province of Utrecht";
          city = "Utrecht";
          product = PRODUCT;
        };
      }
      ''
        DOWNLOADID=$(
          curl --silent --compressed "$DOWNLOADSURL" \
            | jq --raw-output '.downloads[] | .urls.Linux?[]? | select(.downloadTitle | test("^'"$PRODUCT $VERSION"'( Update)?$")) | .downloadId'
        )
        test -n "$DOWNLOADID"
        RESOLVEURL=$(curl \
          --silent \
          --header 'Host: www.blackmagicdesign.com' \
          --header 'Accept: application/json, text/plain, */*' \
          --header 'Origin: https://www.blackmagicdesign.com' \
          --header "$USERAGENT" \
          --header 'Content-Type: application/json;charset=UTF-8' \
          --header "Referer: https://www.blackmagicdesign.com/support/download/$REFERID/Linux" \
          --header 'Accept-Encoding: gzip, deflate, br' \
          --header 'Accept-Language: en-US,en;q=0.9' \
          --header 'Authority: www.blackmagicdesign.com' \
          --header 'Cookie: _ga=GA1.2.1849503966.1518103294; _gid=GA1.2.953840595.1518103294' \
          --data-ascii "$REQJSON" \
          --compressed \
          "$SITEURL/$DOWNLOADID")
        curl \
          --retry 3 --retry-delay 3 \
          --header "Upgrade-Insecure-Requests: 1" \
          --header "$USERAGENT" \
          --header 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' \
          --header 'Accept-Language: en-US,en;q=0.9' \
          --compressed \
          "$RESOLVEURL" \
          > $out
      '';
  patchedStdenv = stdenv // {
    mkDerivation =
      attrs:
      stdenv.mkDerivation (
        if (attrs.pname or null) == "davinci-resolve" then attrs // { src = source; } else attrs
      );
  };
in
pkgs.callPackage (pkgs.path + "/pkgs/by-name/da/davinci-resolve/package.nix") {
  stdenv = patchedStdenv;
}
