.DEFAULT_GOAL := all
.PHONY: all test clean install uninstall

all: ppx_monoid.native

ppx_monoid.native: src/*.ml
	ocamlbuild \
      -use-ocamlfind \
      -package compiler-libs \
      -package ppx_tools.metaquot \
      -package ppx_tools \
      src/ppx_monoid.native

test.native: ppx_monoid.native test/*.ml
	ocamlbuild \
      -use-ocamlfind \
      -package oUnit \
      -cflags -ppx,../ppx_monoid.native \
      test/test.native

install: ppx_monoid.native META
	@ocamlfind install ppx_monoid META ppx_monoid.native

uninstall:
	@ocamlfind remove ppx_monoid

test: test.native
	@./test.native

clean:
	rm -rf _build
	rm -f ppx_monoid.native
	rm -f test.native
	rm -f META
	rm -f oUnit-anon.cache

PKG_VERSION := 0.2

META: META.in
	@sed 's/$$(pkg_version)/$(PKG_VERSION)/g' < $< > $@
