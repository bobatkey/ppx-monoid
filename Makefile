.DEFAULT_GOAL := all
.PHONY: all test clean

SRCDIR := src
include OCamlSrcs.makefile

SRCDIR   := test
PPX_BINS := src/_build/native_bin/ppx_monoid
include OCamlSrcs.makefile

all: src/_build/native_bin/ppx_monoid

test: test/_build/native_bin/test
	@test/_build/native_bin/test

clean:
	rm -rf src/_build
	rm -rf test/_build

