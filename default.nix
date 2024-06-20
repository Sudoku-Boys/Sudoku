{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation {
  name = "Sudoku";
  src = ./.;

  buildInputs = with pkgs; [
    zig
    shaderc
    glfw
    vulkan-headers
    vulkan-loader
    vulkan-validation-layers
    wayland
  ];

  nativeBuildInputs = with pkgs; [
    makeWrapper
  ];

  LD_LIBRARY_PATH = with pkgs; lib.makeLibraryPath [
    shaderc
    glfw
    vulkan-headers
    vulkan-loader
    vulkan-validation-layers
    wayland
  ];

  XDG_CACHE_HOME = "xdg_cache";

  buildPhase = ''
    zig build
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp zig-out/bin/Sudoku $out/bin
    cp summer_rain_rain.flac $out/bin
    cp -r assets $out/bin
  '';

  postFixup = ''
    wrapProgram $out/bin/Sudoku \
      --set LD_LIBRARY_PATH ${with pkgs; lib.makeLibraryPath  [
        shaderc
        glfw
        vulkan-headers
        vulkan-loader
        vulkan-validation-layers
        wayland
      ]}
  '';
}
