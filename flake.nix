{
  description = "Calibre-Web-Automated distroless image (uv2nix)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, pyproject-nix, uv2nix, pyproject-build-systems, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # ---- CI updates ----
        cwaRev = "v4.0.6";
        cwaSha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        # -------------------

        src = pkgs.fetchFromGitHub {
          owner = "crocodilestick";
          repo = "Calibre-Web-Automated";
          rev = cwaRev;
          sha256 = cwaSha256;
        };

        # Patch pyproject.toml and add dummy calibreweb module
        patchedSrc = pkgs.runCommand "cwa-patched-src" { buildInputs = [ pkgs.python3 ]; } ''
          cp -r ${src} $out
          chmod -R +w $out
          # 1. Add calibreweb to build-system.requires
          sed -i '/requires = \[/a\    "calibreweb",' $out/pyproject.toml
          # 2. Explicitly set packages to ['cps'] to avoid flat-layout error
          sed -i '/dynamic = \["version"\]/a packages = ["cps"]' $out/pyproject.toml
          # 3. Create dummy calibreweb module with __version__
          mkdir -p $out/calibreweb
          echo '__version__ = "${builtins.substring 1 (builtins.stringLength cwaRev) cwaRev}"' > $out/calibreweb/__init__.py
        '';

        python = pkgs.python312;

        workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = patchedSrc; };

        uvLockedOverlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };

        pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
          inherit python;
          overrides = [ uvLockedOverlay ];
        });

        cwa = pythonSet.calibre-web-automated;
        cwaVersion = cwa.version or (builtins.substring 1 (builtins.stringLength cwaRev) cwaRev);
      in
      {
        packages.default = pkgs.dockerTools.buildLayeredImage {
          name = "calibre-web-automated";
          tag = "latest";
          contents = [
            cwa
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
            Cmd = [ "${cwa}/bin/cps" ];
            User = "1000";
            WorkingDir = "/config";
          };
        };
        calibreWebAutomatedVersion = cwaVersion;
      });
}
