#!/bin/bash

mkdir -p _tmp

(
    cd _tmp

    repositories=(
	"cilk-plus-rts-with-stats"
	"cmdline"
	"pbench"
	"chunkedseq"
	"sptl"
	"pbbs-include"
	"pbbs-sptl" )
    
    for repo in "${repositories[@]}"
    do
	git clone https://github.com/deepsea-inria/$repo
    done

    package_name=benchmark-pbbs-sptl

    out_folder=$package_name
    rm -rf $out_folder
    mkdir $out_folder
    
    for fname in $( find . -name *.nix ); do
	file=$(basename $fname)
	dir=$(dirname $fname)
	target="$out_folder/$dir"
	mkdir -p $target
	cp $fname $target
    done

    tarball=$package_name.tar.gz

    tar -czvf $tarball $out_folder

    mv $tarball ..

)

rm -rf _tmp
