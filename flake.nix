{
  description = "Calibre-Web-Automated distroless image";

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
          __noChroot = true;
          src = pkgs.fetchFromGitHub {
            owner = "crocodilestick";
            repo = "Calibre-Web-Automated";
            rev = "v4.0.6";                      # CI updates this
            sha256 = "0y3a7w0lcqlslc4l2ygnbkn9c4gva4fbkmmqg1rdigwjr33c86z0";       # CI updates this
          };
          nativeBuildInputs = with pkgs; [ python3 cacert libffi openssl ];
          buildCommand = ''
            export LD_LIBRARY_PATH=${pkgs.libffi}/lib:${pkgs.openssl}/lib
            python3 -m venv $out
            source $out/bin/activate
            pip install --no-cache-dir -r $src/requirements.txt
            pip install --no-cache-dir -r $src/optional-requirements.txt
            pip install --no-cache-dir $src
            # Remove pip+setuptools to shrink image
            rm -rf $out/lib/python*/site-packages/pip*
            rm -rf $out/lib/python*/site-packages/setuptools*
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
        Cmd = [ "/cwa-pip-env/bin/cps" ];
        User = "1000";
        WorkingDir = "/config";
      };
    };
    calibreWebAutomatedVersion = "v4.0.6";
  };
}
