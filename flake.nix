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

    # Generated dependencies (list of Python packages)
    deps = (import ./deps.nix) { inherit pkgs; };

    # Python environment containing all required packages
    pythonEnv = pkgs.python3.withPackages (_: deps);

  in {
    packages.${system}.calibre-web-automated = pkgs.dockerTools.buildLayeredImage {
      name = "calibre-web-automated";
      tag = "latest";
      contents = [
        pythonEnv
        src
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
        Cmd = [ "${pythonEnv}/bin/python" "${src}/cps.py" ];
        User = "1000";
        WorkingDir = "/config";
      };
    };
    calibreWebAutomatedVersion = cwaRev;
  };
}
