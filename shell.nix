{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    zig_0_12
    shaderc
    glfw
    vulkan-headers
    vulkan-loader
    vulkan-validation-layers
    wayland
  ];

  buildInputs = with pkgs; [
    glfw
  ];

  LD_LIBRARY_PATH = with pkgs; lib.makeLibraryPath [
    shaderc
    glfw
    vulkan-headers
    vulkan-loader
    vulkan-validation-layers
    wayland
  ];
}
