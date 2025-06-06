{
  inputs = {
    nixpkgs.url = "https://nixos.org/channels/nixos-unstable/nixexprs.tar.xz";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
    }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ (import rust-overlay) ];
      };
      # TODO: once rust 1.87 (nixos/nixpkgs#407444) hits unstable
      # and davidlattimore/wild#831 no longer depends on rust nightly,
      # we should switch to the standard nixpkgs rustPlatform
      rustToolchain = pkgs.rust-bin.beta.latest.minimal;
      rustPlatform = pkgs.makeRustPlatform {
        rustc = rustToolchain;
        cargo = rustToolchain;
      };
    in
    {
      packages.${system}.default = pkgs.callPackage ./wild.nix { inherit rustPlatform; };
    };
}
