{ pkgs   ? import <nixpkgs> {},
  stdenv ? pkgs.stdenv,
  preExistingDataFolder ? "",
  buildDocs ? false
}:

# To call,
#   nix-shell -p 'with (import <nixpkgs> {}); callPackage ~/Work/pbbs-sptl/script/benchmark.nix { preExistingDataFolder="/run/media/rainey/157ddd80-bedc-4915-ba50-649d191a758e/oracle-guided-data/"; }' --pure -p hwloc ipfs ocaml R texlive.combined.scheme-full
#
# nix-build -E 'with (import <nixpkgs> {}); callPackage ./pbbs-sptl/script/benchmark.nix { preExistingDataFolder="/home/mrainey/pctl_data/"; }'

# Later:
#  - use ipfs over http
#  - get hwloc ocaml R and texlive to be runtime dependencies
#  - make hwloc option a la mkOption
#  - fix the build docs
#  - find a way to pass source files cleanly via fetchFromGithub

let

  callPackage = pkgs.lib.callPackageWith (pkgs // self);

  self = {

    cilk-plus-rts-with-stats = callPackage ../../cilk-plus-rts-with-stats/script/default.nix { };

    cmdline = callPackage ../../cmdline/script/default.nix { };

    pbench = callPackage ../../pbench/script/default.nix { };

    chunkedseq = callPackage ../../chunkedseq/script/default.nix { };

    sptl = callPackage ../../sptl/script/default.nix { };

    pbbs-include = callPackage ../../pbbs-include/default.nix { };

    pbbs-sptl = callPackage ./default.nix { useHwloc = true; };

  };
  
in

stdenv.mkDerivation rec {

  name = "benchmark";
  
  src = ./.;

  buildInputs = [
    self.cmdline self.pbench self.chunkedseq self.sptl
    self.pbbs-include self.pbbs-sptl
  ];

  installPhase =
    let dataFolderInit =
      if preExistingDataFolder == "" then
        "mkdir -p bench/_data/"
      else
        "ln -s ${preExistingDataFolder} bench/_data";
    in
    ''
      mkdir -p $out/bin
      cat >> $out/bin/install-script <<__EOT__
      #!/bin/bash
      cp -r --no-preserve=mode ${self.pbbs-sptl}/bench/ bench/
      ${dataFolderInit}
      mkdir -p pbench/
      cp -r --no-preserve=mode ${self.pbench}/lib/ pbench/
      cp -r --no-preserve=mode ${self.pbench}/xlib/ pbench/
      cp -r --no-preserve=mode ${self.pbench}/tools/ pbench/
      cp --no-preserve=mode ${self.pbench}/Makefile_common ${self.pbench}/timeout.c pbench/
      __EOT__
      chmod u+x $out/bin/install-script
      ln -s ${self.pbench}/bin/prun $out/bin/prun
      ln -s ${self.pbench}/bin/pplot $out/bin/pplot
    '';

}
