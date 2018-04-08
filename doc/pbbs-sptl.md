% Oracle-guided granularity control
% Umut Acar; Vitaly Aksenov; Arthur Charguéraud; Mike Rainey;
% Project page

Overview
========

- The original version of this work appears first as a conference
  paper [@ORACLE_GUIDED_OOPSLA_11] and later as a journal version
  [@ORACLE_GUIDED_JFP_16].

- The current work is reported in a preprint that is being prepared
  for submission to a conference [@ORACLE_GUIDED_18].

How to repeat the experimental evaluation
=========================================

If you encounter difficulties while using this guide, please email
[Mike Rainey](mailto:me@mike-rainey.site).

Prerequisites
-------------

To have enough room to run the experiments, your filesystem should
have about 300GB of free hard-drive space and your machine at least
128GB or RAM. These space requirements are so large because some of
the input graphs we use are huge.

How to build the benchmarks
---------------------------

The first step is to install the [nix](http://nixos.org) build tool on
your test machine. 

After you have nix, create a new folder and change to it. To get the
build script, download the [pbbs-sptl
repository](https://github.com/deepsea-inria/pbbs-sptl.git). Then, run
the following command.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ nix-build -E 'with (import <nixpkgs> {}); \
    callPackage ./pbbs-sptl/script/benchmark.nix { }'
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Alternatively, if you already have a copy of the input data, then run
the following command instead, pointing `pathToInputData` to the
folder.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ nix-build -E 'with (import <nixpkgs> {}); \
    callPackage ./pbbs-sptl/script/benchmark.nix \
      { pathToInputData="<path to the input data>"; }'
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If the command succeeds, there will be a symlink named `result` in the
current directory.

The next step is to create a scratch space in which to run the
experiments.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ ./result/bin/install-script
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We can now change to the scratch folder and build the benchmarking
tool.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ cd bench
$ make bench.pbench
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The script supports running one benchmark at a time. Let's start by
running the convexhull benchmark. 

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ bench.pbench compare -benchmark convexhull
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

How to run the experiments
--------------------------

After this step completes successfully, there should appear in the
`bench` folder a number of new text files of the form `results_*.txt`
and a PDF named `tables_compare.pdf`. The results in the table are,
however, premature at the moment, because there are too few samples to
make any conclusions.

It is possible to collect additional samples by running the following
command.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ bench.pbench compare -benchmark convexhull -runs 29 -mode append
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

So far, we have run only the `convexhull` benchmarks. All the other
benchmarks featured in the paper are also available to run.

- `radixsort`
- `samplesort`
- `suffixarray`
- `convexhull`
- `nearestneighbors`
- `delaunay`
- `raycast`
- `mis`
- `mst`
- `spanning`

As such, we can run `mst` and `spanning` as follows.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ bench.pbench compare -benchmark mst,spanning
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Or, alternatively, we can just run all of the benchmarks.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ bench.pbench compare
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

How to interpret the results
----------------------------

After running the benchmarks, the raw results that were collected from
each benchmark run should appear in text files in the
`pbbs-sptl/bench` folder. These results are fairly human readable, but
the more efficient way to interpret them is to look at the table. In
the same directory, there should now appear a file named
`tables_compare.pdf`. This table should look similar to the one given
in [@ORACLE_GUIDED_18]. The source for the table can be found in
`pbbs-sptl/bench/_results/latex.tex`.

Team
====

- [Umut Acar](http://www.umut-acar.org/site/umutacar/)
- Vitaly Aksenov
- [Arthur Charguéraud](http://www.chargueraud.org/)
- [Mike Rainey](http://gallium.inria.fr/~rainey/)

References
==========