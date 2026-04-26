{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ (self: super: { calibre-web-automated = super.callPackage ./package.nix { }; }) ];
    };
  in {
    packages.${system}.calibre-web-automated = pkgs.dockerTools.buildLayeredImage {
      name = "calibre-web-automated";
      contents = [ pkgs.calibre-web-automated pkgs.calibre pkgs.kepubify pkgs.cacert pkgs.tzdata ];
      config = {
        Cmd = [ "${pkgs.calibre-web-automated}/bin/cps" ];
        ExposedPorts = { "8083/tcp" = {}; };
        Volumes = { "/config" = {}; "/books" = {}; };
        User = "1000";
      };
    };
  };
}
