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
#  - fix the build docs

let

  callPackage = pkgs.lib.callPackageWith (pkgs // sources // self);

  self = {

    hwloc = pkgs.hwloc;

    cilk-plus-rts-with-stats = callPackage "${sources.cilkRtsSrc}/script/default.nix" { };

    cmdline = callPackage "${sources.cmdlineSrc}/script/default.nix" { };

    pbench = callPackage "${sources.pbenchSrc}/script/default.nix" { };

    chunkedseq = callPackage "${sources.chunkedseqSrc}/script/default.nix" { };

    sptl = callPackage "${sources.sptlSrc}/script/default.nix" { };

    pbbs-include = callPackage "${sources.pbbsIncludeSrc}/default.nix" { };

    pbbs-sptl = callPackage "${sources.pbbsSptlSrc}/script/default.nix" { useHwloc = true; };

  };

in

with self;

stdenv.mkDerivation rec {

  name = "benchmark";
  
  src = ./.;

  buildInputs = [
    cmdline pbench chunkedseq sptl pbbs-include pbbs-sptl
  ];

  installPhase =
    let dataFolderInit =
      if pathToInputData == "" then
        "mkdir -p bench/_data/"
      else
        "ln -s ${pathToInputData} bench/_data";
    in
    let getNbCoresScript = pkgs.writeScript "get-nb-cores" ''
      #!/usr/bin/env bash
      nb_cores=$( ${hwloc}/bin/hwloc-ls --only core | wc -l )
      echo $nb_cores > nb_cores
    '';
    in
    let installScript = pkgs.writeScript "install-script" ''
      #!/usr/bin/env bash
      cp -r --no-preserve=mode ${pbbs-sptl}/bench/ bench/
      cp ${getNbCoresScript} bench/get-nb-cores
      ${dataFolderInit}
      mkdir -p pbench/
      cp -r --no-preserve=mode ${pbench}/lib/ pbench/
      cp -r --no-preserve=mode ${pbench}/xlib/ pbench/
      cp -r --no-preserve=mode ${pbench}/tools/ pbench/
      cp --no-preserve=mode ${pbench}/Makefile_common ${pbench}/timeout.c pbench/
    '';
    in
    ''
      mkdir -p $out/bin
      cp ${installScript} $out/bin/install-script
      cp ${getNbCoresScript} $out/bin/get-nb-cores
      chmod u+x $out/bin/install-script
      ln -s ${pbench}/bin/prun $out/bin/prun
      ln -s ${pbench}/bin/pplot $out/bin/pplot
    '';

}
