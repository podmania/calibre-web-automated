{
  description = "Calibre-Web-Automated distroless image (pyproject-nix)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pyproject-nix.url = "github:pyproject-nix/pyproject.nix";
  };

  outputs = { self, nixpkgs, pyproject-nix, ... }: let
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

    # Load requirements.txt from the flake's root directory
    # (CI will fetch and commit the combined requirements file)
    project = pyproject-nix.lib.project.loadRequirementsTxt { projectRoot = ./.; };

    # Build Python environment with all packages from nixpkgs
    pythonEnv = pkgs.python3.withPackages (project.renderers.withPackages { inherit (pkgs) python3; });

    # The application source (not installed, just copied)
    app = pkgs.runCommand "cwa-source" { } ''
      mkdir -p $out
      cp -r ${src}/* $out/
    '';

  in {
    packages.${system}.calibre-web-automated = pkgs.dockerTools.buildLayeredImage {
      name = "calibre-web-automated";
      tag = "latest";
      contents = [
        pythonEnv
        app
        pkgs.calibre
        pkgs.kepubify
        pkgs.cacert
        pkgs.tzdata
      ];
      config = {
        Env = [
          "PORT=8083"
          "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
          "PYTHONPATH=${app}"
        ];
        ExposedPorts = { "8083/tcp" = {}; };
        Volumes = { "/config" = {}; "/books" = {}; };
        Cmd = [ "${pythonEnv}/bin/python" "${app}/cps.py" ];
        User = "1000";
        WorkingDir = "/config";
      };
    };
    calibreWebAutomatedVersion = cwaRev;
  };
}
