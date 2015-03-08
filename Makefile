VERSION := 0.1

PACKAGES := -package compiler-libs.common \
            -package ppx_tools \
            -package ppx_tools.metaquot

OCAMLOPT := ocamlfind ocamlopt -w A-4-9 $(PACKAGES)

############################################################################
.PHONY: all clean install uninstall

all: _build/ppx_monoid _build/META

install: all
	@ocamlfind install ppx_monoid _build/META _build/ppx_monoid

uninstall:
	@ocamlfind remove ppx_monoid

clean:
	rm -rf _build

############################################################################
_build/ppx_monoid.cmx: ppx_monoid.ml
	@echo $@
	@mkdir -p _build
	@$(OCAMLOPT) -o $@ -c $<

_build/ppx_monoid: _build/ppx_monoid.cmx
	@echo $@
	@mkdir -p _build
	@$(OCAMLOPT) -linkpkg -o $@ $^

_build/META: META.in
	@echo $@
	@mkdir -p _build
	sed 's/$$(pkg_version)/$(VERSION)/g' < $< > $@
