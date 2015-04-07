PKG_VERSION := 0.1

PACKAGES := -package compiler-libs.common \
            -package ppx_tools \
            -package ppx_tools.metaquot

TEST_PACKAGES := -package oUnit

OCAMLOPT := ocamlfind ocamlopt -w A-4-9

############################################################################
.PHONY: all clean install uninstall test

all: _build/ppx_monoid _build/META

install: all
	@ocamlfind install ppx_monoid _build/META _build/ppx_monoid

uninstall:
	@ocamlfind remove ppx_monoid

clean:
	rm -rf _build

test: _build/test
	@_build/test

############################################################################
_build:
	@mkdir -p $@

_build/ppx_monoid.cmx: src/ppx_monoid.ml | _build
	@echo $@
	@$(OCAMLOPT) $(PACKAGES) -o $@ -c $<

_build/ppx_monoid: _build/ppx_monoid.cmx | _build
	@echo $@
	@$(OCAMLOPT) $(PACKAGES) -linkpkg -o $@ $^

_build/META: META.in | _build
	@echo $@
	@sed 's/$$(pkg_version)/$(PKG_VERSION)/g' < $< > $@

_build/test.cmx: test/test.ml _build/ppx_monoid | _build
	@echo $@
	@$(OCAMLOPT) $(TEST_PACKAGES) -w -44 -ppx _build/ppx_monoid -o $@ -c $<

_build/test: _build/test.cmx | _build
	@echo $@
	@$(OCAMLOPT) $(TEST_PACKAGES) -linkpkg $^ -o $@
