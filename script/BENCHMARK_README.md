
Install the benchmarking package
================================

Now, run the following command.

    $ nix-build -E 'with (import <nixpkgs> {}); callPackage ./pbbs-sptl/script/benchmark.nix { }'

Alternatively, if you already have a copy of the input data, then run
the following command instead, pointing `preExistingDataFolder` to the
folder.

    $ nix-build -E 'with (import <nixpkgs> {}); callPackage ./pbbs-sptl/script/benchmark.nix { preExistingDataFolder="<path to your custom folder>"; }'

If the command succeeds, there will be a symlink named `result` in the
current directory.

Create a workspace for the experiment
=====================================

The next step is to create a scratch space in which to run the
experiments.

    $ ./result/bin/install-script

Start running an experiment
===========================

We can now change to the scratch folder and build the benchmarking
tool.

    $ cd bench
    $ make bench.pbench

We can now try to run one of the benchmark programs, say,
`convexhull`.

    $ ./bench.pbench compare -benchmark convexhull

If the runs completed successfully, then there should be a file named
`tables_compare.pdf` in the current directory.