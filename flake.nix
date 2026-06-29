{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    openscreen = {
      url = "git+https://chromium.googlesource.com/openscreen.git?rev=934f2462ad01c407a596641dbc611df49e2017b4&submodules=1";
      flake = false;
    };
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # arm64 only supported on linux according to openscreen upstream
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        packages = rec {
          shanocast = default;
          default = pkgs.callPackage ./cast_receiver.nix { src = inputs.openscreen; };
          shanocast-static =
            let
              staticSDL2 = (pkgs.pkgsStatic.SDL2.override {
                dbusSupport = false;
                drmSupport = false;
                ibusSupport = false;
                libdecorSupport = false;
                openglSupport = false;
                pipewireSupport = false;
                pulseaudioSupport = false;
                udevSupport = false;
                waylandSupport = false;
                withStatic = true;
              }).overrideAttrs (_: {
                postFixup = "";
              });
              staticLibopus = pkgs.pkgsStatic.libopus.overrideAttrs (_: {
                doCheck = false;
              });
              staticFfmpeg = pkgs.pkgsStatic.ffmpeg.override {
                libopus = staticLibopus;
                withDrm = false;
                withJack = false;
                withOpencl = false;
                withOpengl = false;
                withPulse = false;
                withSdl2 = false;
                withSoxr = false;
                withSrt = false;
                withVaapi = false;
                withV4l2 = false;
                withV4l2M2m = false;
                withVdpau = false;
                withXvid = false;
              };
            in
            pkgs.pkgsStatic.callPackage ./cast_receiver.nix {
              src = inputs.openscreen;
              ffmpeg = staticFfmpeg;
              SDL2 = staticSDL2;
            };
        };
      };
    };
}
