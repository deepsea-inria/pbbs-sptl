
Create the benchmarking tarball
===============================

The first step is to run the build script.

    $ cd pbbs-sptl/script
    $ ./create-benchmark-nix-package.sh

If the script completes successfully, there will be a file named
`benchmark-pbbs-sptl.tar.gz` in the current directory.

Install the benchmarking package
================================

Once you have the benchmarking tarball, unpack the tarball in a
temporary folder.

    $ tar -xvzf benchmark-pbbs-sptl.tar.gz

Now, run the following command.

    $ nix-build -E 'with (import <nixpkgs> {}); callPackage ./benchmark-pbbs-sptl/pbbs-sptl/script/benchmark.nix { }'

Alternatively, if you already have a copy of the input data, then run
the following command instead, pointing `preExistingDataFolder` to the
folder.

    $ nix-build -E 'with (import <nixpkgs> {}); callPackage ./benchmark-pbbs-sptl/pbbs-sptl/script/benchmark.nix { preExistingDataFolder="<path to your custom folder>"; }'

If the command succeeds, there will be a symlink named `result` in the
current directory.

