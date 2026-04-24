{
  description = "Calibre-Web-Automated Distroless image";

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

        # ---- CI updates these two lines ----
        cwaRev = "v4.0.6";
        cwaSha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        # -----------------------------------

        src = pkgs.fetchFromGitHub {
          owner = "crocodilestick";
          repo = "Calibre-Web-Automated";
          rev = cwaRev;
          sha256 = cwaSha256;
        };

        # Python interpreter
        python = pkgs.python312;

        # Load the uv workspace from the fetched source (requires uv.lock inside)
        workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = src; };

        # Generate Nix overlay from uv.lock, preferring wheels for speed
        uvLockedOverlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };

        # Build the final Python package set with the overlay
        pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
          inherit python;
          overrides = [ uvLockedOverlay ];
        });

        # The Calibre-Web-Automated package
        cwa = pythonSet.calibre-web-automated;

        # Extract version from the package (or fallback to rev)
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
            Volumes = {
              "/config" = {};
              "/books" = {};
            };
            # The actual entry point as defined in pyproject.toml
            Cmd = [ "${cwa}/bin/cps" ];
            User = "1000";
            WorkingDir = "/config";
          };
        };

        # Expose the version for CI (so the build workflow can tag the image)
        calibreWebAutomatedVersion = cwaVersion;
      }
    );
}
