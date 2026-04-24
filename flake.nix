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
            sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # CI updates this
          };
          nativeBuildInputs = with pkgs; [
            python3
            cacert
            libffi
            openssl
            openldap        # for python-ldap
            cyrus_sasl      # for python-ldap
            pkg-config      # helps find libraries
          ];
          buildCommand = ''
            # Set paths for compiler to find ldap and sasl headers/libraries
            export CPPFLAGS="-I${pkgs.openldap}/include -I${pkgs.cyrus_sasl}/include"
            export LDFLAGS="-L${pkgs.openldap}/lib -L${pkgs.cyrus_sasl}/lib"
            export LD_LIBRARY_PATH="${pkgs.libffi}/lib:${pkgs.openssl}/lib:${pkgs.openldap}/lib:${pkgs.cyrus_sasl}/lib"

            python3 -m venv $out
            source $out/bin/activate

            # Install python-ldap first
            pip install --no-cache-dir --no-binary=python-ldap python-ldap

            # Install all dependencies from requirements files
            pip install --no-cache-dir -r $src/requirements.txt
            pip install --no-cache-dir -r $src/optional-requirements.txt

            # Install the application itself
            pip install --no-cache-dir $src

            # Remove pip and setuptools to reduce size
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
