{ pkgs   ? import <nixpkgs> {},
  stdenv ? pkgs.stdenv,
  sources ? import ./default-sources.nix,
  pathToInputData ? "",
  buildDocs ? false
}:

# To call,
#   nix-shell -p 'with (import <nixpkgs> {}); callPackage ~/Work/pbbs-sptl/script/benchmark.nix { pathToInputData="/run/media/rainey/157ddd80-bedc-4915-ba50-649d191a758e/oracle-guided-data/"; }' --pure -p hwloc ipfs ocaml R texlive.combined.scheme-full
#
# nix-build -E 'with (import <nixpkgs> {}); callPackage ./pbbs-sptl/script/benchmark.nix { pathToInputData="/home/mrainey/pctl_data/"; }'

# Later:
#  - use ipfs over http
#  - get hwloc ocaml R and texlive to be runtime dependencies
#  - make hwloc option a la mkOption
#  - fix the build docs

let

  callPackage = pkgs.lib.callPackageWith (pkgs // sources // self);

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

with self;

stdenv.mkDerivation rec {

  name = "benchmark";
  
  src = ./.;

  buildInputs = [
    cmdline pbench chunkedseq sptl
    pbbs-include pbbs-sptl
  ];

  installPhase =
    let dataFolderInit =
      if pathToInputData == "" then
        "mkdir -p bench/_data/"
      else
        "ln -s ${pathToInputData} bench/_data";
    in
    ''
      mkdir -p $out/bin
      cat >> $out/bin/install-script <<__EOT__
      #!/bin/bash
      cp -r --no-preserve=mode ${pbbs-sptl}/bench/ bench/
      ${dataFolderInit}
      mkdir -p pbench/
      cp -r --no-preserve=mode ${pbench}/lib/ pbench/
      cp -r --no-preserve=mode ${pbench}/xlib/ pbench/
      cp -r --no-preserve=mode ${pbench}/tools/ pbench/
      cp --no-preserve=mode ${pbench}/Makefile_common ${pbench}/timeout.c pbench/
      __EOT__
      chmod u+x $out/bin/install-script
      ln -s ${pbench}/bin/prun $out/bin/prun
      ln -s ${pbench}/bin/pplot $out/bin/pplot
    '';

}
