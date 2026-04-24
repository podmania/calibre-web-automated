{
  description = "Calibre-Web-Automated image";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    system = builtins.currentSystem;
    pkgs = nixpkgs.legacyPackages.${system};

    # ---- CI updates these two lines ----
    cwaRev = "v4.0.6";
    cwaSha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    # --------------------------------

  in {
    packages.${system}.calibre-web-automated = pkgs.dockerTools.buildLayeredImage {
      name = "calibre-web-automated";
      tag = "latest";
      contents = [
        (pkgs.stdenv.mkDerivation {
          name = "cwa-pip-env";
          src = pkgs.fetchFromGitHub {
            owner = "crocodilestick";
            repo = "Calibre-Web-Automated";
            rev = cwaRev;
            sha256 = cwaSha256;
          };
          nativeBuildInputs = with pkgs; [ python3 cacert ];
          buildCommand = ''
            python3 -m venv $out
            source $out/bin/activate
            pip install --no-cache-dir -r $src/requirements.txt
            pip install --no-cache-dir -r $src/optional-requirements.txt
            pip install --no-cache-dir $src
            rm -rf $out/lib/python*/site-packages/pip*
            rm -rf $out/lib/python*/site-packages/setuptools*
            mkdir -p $out/bin
            ln -s $out/bin/cps $out/bin/calibre-web-automated
          '';
        })
        pkgs.calibre
        pkgs.kepubify
        pkgs.cacert
        pkgs.tzdata
      ];
      config = {
        Env = [
          "PORT=8083"
          "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
        ];
        ExposedPorts = { "8083/tcp" = {}; };
        Volumes = { "/config" = {}; "/books" = {}; };
        Cmd = [ "/cwa-pip-env/bin/calibre-web-automated" ];
        User = "1000";
        WorkingDir = "/config";
      };
    };

    # For CI to read the current version
    calibreWebAutomatedVersion = cwaRev;
  };
}
