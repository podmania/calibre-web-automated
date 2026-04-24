{
  description = "Calibre-Web-Automated distroless image (pip-based)";

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
          name = "cwa-pip-env";
          __noChroot = true;
          inherit src;
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
            cp -r $src /tmp/cwa-src
            chmod -R +w /tmp/cwa-src
            cd /tmp/cwa-src

            # Remove problematic pyproject.toml
            rm -f pyproject.toml

            # Inject correct setup.py with entry_points
            cat > setup.py <<EOF
            from setuptools import setup
            setup(
                name="calibre-web-automated",
                version="${builtins.substring 1 (builtins.stringLength cwaRev) cwaRev}",
                packages=["cps"],
                package_dir={"cps": "cps"},
                include_package_data=True,
                entry_points={
                    "console_scripts": [
                        "cps = cps:main",
                    ],
                },
            )
            EOF

            export CPPFLAGS="-I${pkgs.openldap}/include -I${pkgs.cyrus_sasl}/include"
            export LDFLAGS="-L${pkgs.openldap}/lib -L${pkgs.cyrus_sasl}/lib"
            export LD_LIBRARY_PATH="${pkgs.libffi}/lib:${pkgs.openssl}/lib:${pkgs.openldap}/lib:${pkgs.cyrus_sasl}/lib"

            python3 -m venv $out
            source $out/bin/activate
            pip install --no-cache-dir --no-binary=python-ldap python-ldap
            pip install --no-cache-dir -r requirements.txt
            pip install --no-cache-dir -r optional-requirements.txt
            pip install --no-cache-dir --no-deps .

            # Fallback: if cps script still missing, create it manually
            if [ ! -f $out/bin/cps ]; then
                cat > $out/bin/cps <<'EOSCRIPT'
            #!$out/bin/python
            from cps import main
            if __name__ == "__main__":
                main()
            EOSCRIPT
                chmod +x $out/bin/cps
            fi

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
    calibreWebAutomatedVersion = cwaRev;
  };
}
