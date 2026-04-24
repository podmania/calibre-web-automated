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
            rev = "v4.0.6";
            sha256 = "0y3a7w0lcqlslc4l2ygnbkn9c4gva4fbkmmqg1rdigwjr33c86z0";
          };
          nativeBuildInputs = with pkgs; [
            python3
            cacert
            libffi
            openssl
            openldap
            cyrus_sasl
            pkg-config
          ];
          buildCommand = ''
            # Create a writable copy of the source
            cp -r $src /tmp/cwa-src
            chmod -R +w /tmp/cwa-src
            cd /tmp/cwa-src

            # Inject a correct setup.py that only includes the 'cps' package
            cat > setup.py <<EOF
            from setuptools import setup
            setup(
                name="calibre-web-automated",
                version="${builtins.substring 1 (builtins.stringLength src.rev) src.rev}",
                packages=["cps"],
                package_dir={"cps": "cps"},
                include_package_data=True,
            )
            EOF

            # Set compiler flags for python-ldap
            export CPPFLAGS="-I${pkgs.openldap}/include -I${pkgs.cyrus_sasl}/include"
            export LDFLAGS="-L${pkgs.openldap}/lib -L${pkgs.cyrus_sasl}/lib"
            export LD_LIBRARY_PATH="${pkgs.libffi}/lib:${pkgs.openssl}/lib:${pkgs.openldap}/lib:${pkgs.cyrus_sasl}/lib"

            # Create virtual environment and install
            python3 -m venv $out
            source $out/bin/activate

            # Install python-ldap first (compiled from source)
            pip install --no-cache-dir --no-binary=python-ldap python-ldap

            # Install all dependencies from requirements files
            pip install --no-cache-dir -r requirements.txt
            pip install --no-cache-dir -r optional-requirements.txt

            # Install the application itself (use --no-deps to avoid re‑installing dependencies)
            pip install --no-cache-dir --no-deps .

            # Remove pip and setuptools to shrink image
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
