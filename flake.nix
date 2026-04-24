{
  description = "Calibre-Web-Automated image";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    system = builtins.currentSystem;
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.${system}.calibre-web-automated = pkgs.dockerTools.buildLayeredImage {
      name = "calibre-web-automated";
      tag = "latest";
      contents = [
        (pkgs.stdenv.mkDerivation {
          name = "cwa-pip-env";
          # ---- CI UPDATES THESE TWO LINES ----
          rev = "v4.0.6";
          sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";  # placeholder
          # -----------------------------------
          src = pkgs.fetchFromGitHub {
            owner = "crocodilestick";
            repo = "Calibre-Web-Automated";
            inherit rev sha256;
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

    # Expose the current version for CI
    calibreWebAutomatedVersion = "v4.0.6";   # CI updates this line too
  };
}
