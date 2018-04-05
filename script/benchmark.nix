{ pkgs   ? import <nixpkgs> {},
  stdenv ? pkgs.stdenv,
  fetchurl,
  preExistingDataFolder ? "",
  buildDocs ? false
}:

# To call,
#   nix-shell -p 'with (import <nixpkgs> {}); callPackage ~/Work/pbbs-sptl/script/benchmark.nix { preExistingDataFolder="/run/media/rainey/157ddd80-bedc-4915-ba50-649d191a758e/oracle-guided-data/"; }' --pure -p hwloc ipfs ocaml R texlive.combined.scheme-full
#
# nix-build -E 'with (import <nixpkgs> {}); callPackage ./pbbs-sptl/script/benchmark.nix { preExistingDataFolder="/home/mrainey/pctl_data/"; }'

let

  gperftools = pkgs.gperftools;

  hwloc = pkgs.hwloc;

  cilk-plus-rts-with-stats = import ../../cilk-plus-rts-with-stats/script/default.nix { inherit pkgs; inherit fetchurl; };

  cmdline = import ../../cmdline/script/default.nix { inherit pkgs; inherit fetchurl; };

  pbench = import ../../pbench/script/default.nix { inherit pkgs; inherit fetchurl; };

  chunkedseq = import ../../chunkedseq/script/default.nix { inherit pkgs; inherit fetchurl; };

  sptl = import ../../sptl/script/default.nix { inherit pkgs;
                                                inherit fetchurl;
                                                chunkedseq = chunkedseq; };

  pbbs-include = import ../../pbbs-include/default.nix { inherit pkgs; inherit fetchurl; };

  pbbs-sptl = import ./default.nix { inherit pkgs;
                                     inherit fetchurl;
                                     inherit pbench;
                                     inherit sptl;
                                     inherit pbbs-include;
                                     inherit cmdline;
                                     inherit chunkedseq;
                                     inherit cilk-plus-rts-with-stats;
                                     inherit gperftools;
                                     inherit hwloc;
                                     useHwloc = true;
                                     };

in

stdenv.mkDerivation rec {

  name = "benchmark";
  
  src = ./.;

  buildInputs = [
    cmdline pbench chunkedseq sptl
    pbbs-include pbbs-sptl
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
