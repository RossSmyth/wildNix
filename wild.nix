{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch,
  makeBinaryWrapper,
  rustPlatform,
  nix-update-script,
  versionCheckHook,
  clang,
  binutils-unwrapped-all-targets,
  gcc,
  glibc,
  lld,
}:
let
  # Write a wrapper for GCC that passes -B to *unwrapped* binutils.
  # This ensures that if -fuse-ld=bfd is used, gcc picks up unwrapped ld.bfd
  # instead of the hardcoded wrapper search directory.
  # We pass it last because apparently gcc likes picking ld from the *first* -B,
  # which we want our wild target directory to be if passed.
  gccWrapper = stdenv.mkDerivation {
    inherit (gcc) meta name;
    dontUnpack = true;
    dontConfigure = true;
    dontInstall = true;

    buildInputs = [ makeBinaryWrapper ];
    buildPhase = ''
      runHook preBuild

      makeWrapper ${lib.getExe gcc} $out/bin/gcc \
        --append-flag -B${binutils-unwrapped-all-targets}/bin

      runHook postBuild
    '';

  };

  gppWrapper = stdenv.mkDerivation {
    dontUnpack = true;
    dontConfigure = true;
    dontInstall = true;

    name = "g++-wrapped";
    buildInputs = [ makeBinaryWrapper ];
    buildPhase = ''
      runHook preBuild

      makeWrapper ${lib.getExe' gcc "g++"} $out/bin/g++ \
        --append-flag -B${binutils-unwrapped-all-targets}/bin

      runHook postBuild
    '';
    meta = gcc.meta // {
      mainProgram = "g++";
    };
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  strictDeps = true;
  pname = "wild";
  version = "main";

  src = fetchFromGitHub {
    owner = "davidlattimore";
    repo = "wild";
    rev = "7c3737c5bae296bf3ed080ce9fba8db9015452a5";
    hash = "sha256-m3hGDS4Rfe73shrwHFtrTNiFSIuMdBhABddKWVzdE+E=";
  };

  patches = [
    (fetchpatch {
      url = "https://github.com/davidlattimore/wild/pull/831.patch";
      hash = "sha256-UywEVaaqnin0PBsRqDLIZXSI6QdtQ9WHetuQrAfUlNo=";
    })
    (fetchpatch {
      url = "https://github.com/davidlattimore/wild/pull/843.patch";
      hash = "sha256-Uq03TzYyrRlZdAcdGfrO781vGM1GkAVoNdI96Vy/k5Y=";
    })
  ];

  useFetchCargoVendor = true;
  cargoHash = "sha256-yHkWxC6ZXNnEhLdVfD6E15AvxM1AOUsdRT1YUTY+uPs=";

  cargoBuildFlags = [ "-p wild-linker" ];

  # wild's tests compare the outputs of several different linkers. nixpkgs's
  # patching and wrappers change the output behavior, so we must make sure
  # that their behavior is compatible.
  checkInputs = [
    glibc.out
    glibc.static
  ];
  checkPhase = ''
    export LD_LIBRARY_PATH=${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}
    export PATH=${
      lib.makeBinPath [
        binutils-unwrapped-all-targets
        clang
        gccWrapper
        gppWrapper
        lld
      ]
    }:$PATH
    cargoCheckHook
  '';

  # TOOD: once v0.6.0 is released with the patches we need, switch to that and
  # start doing version checks
  doInstallCheck = false;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  passthru.updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };

  meta = {
    changelog = "https://github.com/davidlattimore/wild/blob/${finalAttrs.version}/CHANGELOG.md";
    description = "Very fast linker for Linux";
    homepage = "https://github.com/davidlattimore/wild";
    license = [
      lib.licenses.asl20 # or
      lib.licenses.mit
    ];
    mainProgram = "wild";
    maintainers = with lib.maintainers; [ RossSmyth ];
    platforms = [ "x86_64-linux" ];
  };
})
