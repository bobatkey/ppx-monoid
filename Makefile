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
_build/ppx_monoid.cmx: ppx_monoid.ml
	@echo $@
	@mkdir -p _build
	@$(OCAMLOPT) $(PACKAGES) -o $@ -c $<

_build/ppx_monoid: _build/ppx_monoid.cmx
	@echo $@
	@mkdir -p _build
	@$(OCAMLOPT) $(PACKAGES) -linkpkg -o $@ $^

_build/META: META.in
	@echo $@
	@mkdir -p _build
	sed 's/$$(pkg_version)/$(PKG_VERSION)/g' < $< > $@

_build/test.cmx: test.ml _build/ppx_monoid
	@echo $@
	@mkdir -p _build
	@$(OCAMLOPT) $(TEST_PACKAGES) -w -44 -ppx _build/ppx_monoid -o $@ -c $<

_build/test: _build/test.cmx _build/ppx_monoid
	@echo $@
	@mkdir -p _build
	@$(OCAMLOPT) $(TEST_PACKAGES) -linkpkg $< -o $@
