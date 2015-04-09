.DEFAULT_GOAL := all
.PHONY: all test clean install uninstall

SRCDIR := src
include OCamlSrcs.makefile

SRCDIR := test
PPX_BINS := src/_build/native_bin/ppx_monoid
include OCamlSrcs.makefile

######################################################################
all: src/_build/native_bin/ppx_monoid META

install: all
	@ocamlfind install ppx_monoid META src/_build/native_bin/ppx_monoid

uninstall:
	@ocamlfind remove ppx_monoid

test: test/_build/native_bin/test
	@test/_build/native_bin/test

clean:
	rm -rf src/_build
	rm -rf test/_build
	rm -f META
	rm -f oUnit-anon.cache

PKG_VERSION := 0.1

META: META.in
	@sed 's/$$(pkg_version)/$(PKG_VERSION)/g' < $< > $@
