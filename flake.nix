{
  description = "The sudoku game";

  inputs = {
    nixpkgs.url = "nixpkgs";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in
  {
    packages.${system}.default = pkgs.stdenv.mkDerivation {
      name = "sudoku";
      src = ./.;

      buildInputs = with pkgs; [
        zig
        shaderc
        glfw
        vulkan-headers
        vulkan-loader
      ];

      LD_LIBRARY_PATH = with pkgs; pkgs.lib.makeLibraryPath [
        shaderc
        glfw
        vulkan-headers
        vulkan-loader
      ];

      buildPhase = ''
        zig build
      '';

      installPhase = ''
        mkdir -p $out/bin
        cp zig-out/bin/sudoku $out/bin
      '';
    };
  };
}
