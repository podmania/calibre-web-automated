{
  description = "Calibre-Web-Automated distroless image";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    system = builtins.currentSystem;
    pkgs = nixpkgs.legacyPackages.${system};

    # ---- CI updates these lines ----
    cwaRev = "v4.0.6";
    cwaSha256 = "0y3a7w0lcqlslc4l2ygnbkn9c4gva4fbkmmqg1rdigwjr33c86z0";
    # --------------------------------

    src = pkgs.fetchFromGitHub {
      owner = "crocodilestick";
      repo = "Calibre-Web-Automated";
      rev = cwaRev;
      sha256 = cwaSha256;
    };
  in {
    packages.${system}.calibre-web-automated = pkgs.dockerTools.buildLayeredImage {
      name = "calibre-web-automated";
      tag = "latest";
      contents = [
        (pkgs.stdenv.mkDerivation {
          name = "cwa-app";
          __noChroot = true;
          nativeBuildInputs = with pkgs; [ python3 pkg-config openldap cyrus_sasl cacert ];
          buildCommand = ''
            set -e
            mkdir -p $out/app
            cp -r ${src}/* $out/app/

            export PKG_CONFIG_PATH=${pkgs.openldap}/lib/pkgconfig:${pkgs.cyrus_sasl}/lib/pkgconfig

            python3 -m venv $out/venv
            source $out/venv/bin/activate

            pip install --no-cache-dir -r $out/app/requirements.txt
            pip install --no-cache-dir -r $out/app/optional-requirements.txt

            # Clean up
            rm -rf $out/venv/lib/python*/site-packages/pip*
            rm -rf $out/venv/lib/python*/site-packages/setuptools*
          '';
        })
        pkgs.calibre
        pkgs.kepubify
        pkgs.cacert
        pkgs.tzdata
        pkgs.openldap
        pkgs.cyrus_sasl
        pkgs.libffi
        pkgs.openssl
      ];
      config = {
        Env = [
          "PORT=8083"
          "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
          "PYTHONPATH=/app"
        ];
        ExposedPorts = { "8083/tcp" = {}; };
        Volumes = { "/config" = {}; "/books" = {}; };
        Cmd = [ "/venv/bin/python" "/app/cps.py" ];
        User = "1000";
        WorkingDir = "/config";
      };
    };
    calibreWebAutomatedVersion = cwaRev;
  };
}
