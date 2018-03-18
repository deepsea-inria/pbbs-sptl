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

Source code for the prototype
=============================

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

The following packages should be installed on your test machine.

-----------------------------------------------------------------------------------
Package    Version         Details
--------   ----------      --------------------------------------------------------
gcc         >= 6.1         Recent gcc is required because pdfs 
                           makes heavy use of features of C++1x,
                           such as lambda expressions and
                           higher-order templates.
                           ([Home page](https://gcc.gnu.org/))

ocaml        >= 4.02       Ocaml is required to build the
                           benchmarking script.
                           ([Home page](http://www.ocaml.org/))

R            >= 2.4.1      The R tools is used by our scripts to
                           generate plots.
                           ([Home page](http://www.r-project.org/))
                                               
tcmalloc     recent        *Optional dependency* (See instructions below).
                           This package is used to provide a scalable
                           heap allocator 
                           ([Home page](http://goog-perftools.sourceforge.net/doc/tcmalloc.html))

hwloc        recent        *Optional dependency* (See instructions 
                           below). This package is used to force
                           interleaved NUMA allocation; as
                           such this package is optional and only
                           really relevant for NUMA machines.
                           ([Home page](http://www.open-mpi.org/projects/hwloc/))

ipfs         recent        We are going to use this software to
                           download data sets for our experiments.
                           ([Home page](https://ipfs.io/))
-----------------------------------------------------------------------------------

Table: Software dependencies for the benchmarks.

Getting the input data
----------------------

We use IPFS as the tool to disseminate our input data files. After
installing IPFS, we need to initialize the local IPFS configuration.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ ipfs init
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

::::: {#warning-disk-space .warning}

**Warning:** disk space. The default behavior of IPFS is to keep a
cache of all downloaded files in the folder `~/.ipfs/`. Because the
graph data is several gigabytes, the cache folder should have at least
twice this much free space. To select a different cache folder for
IPFS, before issuing the command ipfs init, set the environment
variable `$IPFS_PATH` to point to the desired path.

:::::

In order to use IPFS to download files, the IPFS daemon needs to be
running. You can start the IPFS daemon in the following way, or you
can start it in the background, like a system service. Make sure that
this daemon continues to run in the background until after all of the
input data files you want are downloaded on your test machine.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ ipfs daemon
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

How to build the benchmarks
---------------------------

Our benchmarking script is configured to automatically download the
input data as needed. We can get started by changing to the
benchmarking directory and building the script.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ cd pbbs-sptl/bench
$ make bench.pbench
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

::::: {#optional-heap-allocator .optional}

**Optional:** Using a custom heap allocator

Because it often delivers best results, we recommend running all of
the experiments using the Google's custom heap allocator, namely
[tcmalloc](http://goog-perftools.sourceforge.net/doc/tcmalloc.html). In
general, you can build with any drop-in replacement for
`malloc`/`free` by configuring the benchmark settings appropriately.

To use tcmalloc, for example, we need to insert into the file
`pbbs-sptl/bench/settings.sh` a line like the following.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
CUSTOM_MALLOC_PREFIX=-ltcmalloc
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

It is fine to add to the "custom, malloc prefix" additional arguments,
such as the linker path: `-L $GPERFTOOLS_HOME/lib/`.

:::::

::::: {#optional-hwloc .optional}

**Optional:** Dealing with NUMA

If your test machine is a NUMA machine, then we recommend that, for
best performance on benchmarks, you configure the benchmarks to use
the round-robin page-allocation for NUMA. The existing benchmarking
framework automatically handles this configuration, if the benchmarks
are linked with a library called `hwloc`. As such, to run experiments
on a NUMA machine, we recommend that you insert into the file
`pbbs-sptl/bench/settings.sh` the following line.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
USE_HWLOC=1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Of course, `hwloc` needs to be installed on the test system for the
benchmarks to build with this configuration. Fortunately, it is easy
to check whether `hwloc` is installed: just run the following command,
and if successful, you should see output somewhat like below.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ pkg-config --cflags hwloc
-I/nix/store/lwjvcas5sxs4r3m3r780zkjc4h8a39pb-hwloc-1.11.8-dev/include
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:::::

The script supports running one benchmark at a time. Let's start by
running the convexhull benchmark. Let `$P` denote the number of
processors/cores that you wish to use in the experiments. This number
should be at least two and should be no more than the number of cores
in the system.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ bench.pbench compare -benchmark convexhull -proc 1,$P
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

::::: {#note-hyperthreading .note}

*Note:* If your machine has hyperthreading enabled, then we recommend
running the experiments without and with hyperthreading. To run with
hyperthreading, just set `$P` to be the total number of cores or
hyperthreads in the system as desired. For example, if the machine has
eight cores, with each core having two hyperthreads, then to test
without hyperthreading, set `$P` to be `8`, and to test with
hyperthreading, set `$P$` to be `16`.

:::::

For a variety of reasons, one of the steps involved in the
benchmarking can fail. A likely cause is the failure to obtain the
required input data. The reason is that these files are large, and as
such, we are hosting the files ourselves, using a peer-to-peer
file-transfer protocol called [IPFS](http://ipfs.io). 

::::: {#note-ipfs-ping .note}

*Note:* If you notice that the benchmarking script gets stuck for a
long time while issuing the `ipfs get ...` commands, we recommend
that, in a separate window, you ping one of the machines that we are
using to host our input data.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ ipfs ping QmRBzXmjGFtDAy57Rgve5NbNDvSUJYeSjoGQkdtfBvnbWX
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Please email us if you have to wait for a long time or are having
trouble getting the input data. If IPFS becomes problematic, we are
happy to find other means to distribute the input data.

:::::

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
$ bench.pbench compare -benchmark convexhull -proc $P -runs 29 -mode append
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

::::: {#note-samples .note}

*Note:* In our example, we collect additional samples for runs
involving two or more processors. The reason is that the single-core
runs usually exhibit relatively little noise and, as such, we prefer
to save time running experiments by performing fewer single-core runs.

:::::

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
$ bench.pbench compare -benchmark mst,spanning -proc 1,$P
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Or, alternatively, we can just run all of the benchmarks.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ bench.pbench compare -proc 1,$P
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