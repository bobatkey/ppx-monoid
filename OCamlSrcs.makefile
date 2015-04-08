######################################################################
# Generic OCaml build instructions; uses .merlin file to get the list
# of required ocamlfind packages.
#
# FIXME: is there any way to force a rebuild if the ocamlfind packages
# change? can ocamlfind packages be hashed?
#
# FIXME: abort if there are .ml(i) files that would be overwritten by
# ocamllex or menhir
#
# FIXME: is it possible to have libraries (.cm(x)a) inside other
# libraries?

ifndef SRCDIR
$(error SRCDIR must be set)
endif

BUILDDIR := $(SRCDIR)/_build

ifndef BUILDDIRS
BUILDDIRS := $(BUILDDIR)
else
BUILDDIRS := $(BUILDDIRS) $(BUILDDIR)
endif

BYTE_BINDIR    := $(BUILDDIR)/byte_bin
NATIVE_BINDIR  := $(BUILDDIR)/native_bin

OCAML_LIBS     := $(shell cat $(SRCDIR)/.merlin | grep ^PKG | cut -d' ' -f2)
OCAML_PKGS_OPT := $(foreach lib,$(OCAML_LIBS),-package $(lib))

# FIXME: work out the PPX_BINS from this too, so we can depend on them, and have a proper way of getting the paths corrected

# Use 'realpath -m --relative-to=. $(SRCDIR)/blah' to get proper paths
OCAMLC_FLAGS   := $(patsubst ../%,%,$(shell cat $(SRCDIR)/.merlin | grep ^FLG | sed 's/^FLG //' | tr '\n' ' '))

OCAMLC         := ocamlfind ocamlc $(OCAMLC_FLAGS) $(OCAML_PKGS_OPT)
OCAMLOPT       := ocamlfind ocamlopt $(OCAMLC_FLAGS) $(OCAML_PKGS_OPT)
OCAMLDEP_OPTS  := -I $(SRCDIR)/ -ml-synonym .mll -ml-synonym .mly -mli-synonym .mly
OCAMLDEP       := ocamlfind ocamldep $(OCAML_PKGS_OPT) $(OCAMLDEP_OPTS)
MENHIR         := menhir

######################################################################
$(BUILDDIR):
	@mkdir -p $@

$(BYTE_BINDIR):
	@mkdir -p $@

$(NATIVE_BINDIR):
	@mkdir -p $@

######################################################################
# All of the dependency files (FIXME: don't need this: just include each DEP list immediately)
OCAML_DEPS :=

# OCAML_PRODUCTS contains that could possibly be generated from the
# current source files
ifndef OCAML_PRODUCTS
OCAML_PRODUCTS :=
endif

$(BUILDDIR)/%.d: BUILDDIR      := $(BUILDDIR)
$(BUILDDIR)/%.d: SRCDIR        := $(SRCDIR)
$(BUILDDIR)/%.d: OCAMLDEP      := $(OCAMLDEP)
$(BUILDDIR)/%.d: BYTE_BINDIR   := $(BYTE_BINDIR)
$(BUILDDIR)/%.d: NATIVE_BINDIR := $(NATIVE_BINDIR)

$(BUILDDIR)/%.cmo: OCAMLC      := $(OCAMLC)
$(BUILDDIR)/%.cmo: BUILDDIR    := $(BUILDDIR)
$(BUILDDIR)/%.cmi: OCAMLC      := $(OCAMLC)
$(BUILDDIR)/%.cmi: BUILDDIR    := $(BUILDDIR)
$(BUILDDIR)/%.cmx: OCAMLOPT    := $(OCAMLOPT)
$(BUILDDIR)/%.cmx: BUILDDIR    := $(BUILDDIR)
$(BUILDDIR)/%.cma: OCAMLC      := $(OCAMLC)
$(BUILDDIR)/%.cma: BUILDDIR    := $(BUILDDIR)
$(BUILDDIR)/%.cmxa: OCAMLOPT   := $(OCAMLOPT)
$(BUILDDIR)/%.cmxa: BUILDDIR   := $(BUILDDIR)

$(BYTE_BINDIR)/%: OCAMLC       := $(OCAMLC)
$(BYTE_BINDIR)/%: BUILDDIR     := $(BUILDDIR)
$(NATIVE_BINDIR)/%: OCAMLOPT   := $(OCAMLOPT)
$(NATIVE_BINDIR)/%: BUILDDIR   := $(BUILDDIR)

##################################################
## .ml files
# FIXME: remove .ml that come from .mll or .mly?
OCAML_ML_SRCS     := $(wildcard $(SRCDIR)/*.ml)
OCAML_ML_DEPS     := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_ML_SRCS))
OCAML_ML_PRODUCTS := \
    $(patsubst $(SRCDIR)/%.ml,$(BUILDDIR)/%.cmo,$(OCAML_ML_SRCS)) \
    $(patsubst $(SRCDIR)/%.ml,$(BUILDDIR)/%.cmi,$(OCAML_ML_SRCS)) \
    $(patsubst $(SRCDIR)/%.ml,$(BUILDDIR)/%.o,$(OCAML_ML_SRCS))   \
    $(patsubst $(SRCDIR)/%.ml,$(BUILDDIR)/%.cmx,$(OCAML_ML_SRCS)) \
    $(OCAML_ML_DEPS)
OCAML_DEPS        += $(OCAML_ML_DEPS)
OCAML_PRODUCTS    += $(OCAML_ML_PRODUCTS)

$(OCAML_ML_DEPS): $(BUILDDIR)/%.ml.d: $(SRCDIR)/%.ml $(SRCDIR)/.merlin | $(BUILDDIR)
	@$(OCAMLDEP) $< | sed "s#$(SRCDIR)/#$(BUILDDIR)/#g" > $@

$(BUILDDIR)/%.cmo: $(SRCDIR)/%.ml $(SRCDIR)/.merlin $(PPX_BINS) | $(BUILDDIR) ocaml-tidy
	@echo Compiling module $* '(bytecode)'
	@$(OCAMLC) -I $(BUILDDIR) -o $@ -c $<

$(BUILDDIR)/%.cmx: $(SRCDIR)/%.ml $(SRCDIR)/.merlin $(PPX_BINS) | $(BUILDDIR) ocaml-tidy
	@echo Compiling module $* '(native)'
	@$(OCAMLOPT) -I $(BUILDDIR) -o $@ -c $<

##################################################
## .mli files
# FIXME: remove .mli that come from .mly
OCAML_MLI_SRCS     := $(wildcard $(SRCDIR)/*.mli)
OCAML_MLI_DEPS     := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_MLI_SRCS))
OCAML_MLI_PRODUCTS := \
    $(patsubst $(SRCDIR)/%.mli,$(BUILDDIR)/%.cmi,$(OCAML_MLI_SRCS))  \
    $(OCAML_MLI_DEPS)
OCAML_DEPS         += $(OCAML_MLI_DEPS)
OCAML_PRODUCTS     += $(OCAML_MLI_PRODUCTS)

$(OCAML_MLI_DEPS): $(BUILDDIR)/%.mli.d: $(SRCDIR)/%.mli $(SRCDIR)/.merlin | $(BUILDDIR)
	@$(OCAMLDEP) $< | sed "s#$(SRCDIR)/#$(BUILDDIR)/#g" > $@

$(BUILDDIR)/%.cmi: $(SRCDIR)/%.mli $(SRCDIR)/.merlin $(PPX_BINS) | $(BUILDDIR) ocaml-tidy
	@echo Compiling interface $*
	@$(OCAMLC) -I $(BUILDDIR) -o $@ -c $<

##################################################
## .mll files
OCAML_LEX_SRCS     := $(wildcard $(SRCDIR)/*.mll)
OCAML_LEX_DEPS     := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_LEX_SRCS))
OCAML_LEX_PRODUCTS := \
    $(patsubst $(SRCDIR)/%.mll,$(BUILDDIR)/%.cmo,$(OCAML_LEX_SRCS))  \
    $(patsubst $(SRCDIR)/%.mll,$(BUILDDIR)/%.cmi,$(OCAML_LEX_SRCS))  \
    $(patsubst $(SRCDIR)/%.mll,$(BUILDDIR)/%.o,$(OCAML_LEX_SRCS))    \
    $(patsubst $(SRCDIR)/%.mll,$(BUILDDIR)/%.cmx,$(OCAML_LEX_SRCS))  \
    $(OCAML_LEX_DEPS)
OCAML_DEPS         += $(OCAML_LEX_DEPS)
OCAML_PRODUCTS     += $(OCAML_LEX_PRODUCTS)

$(OCAML_LEX_DEPS): $(BUILDDIR)/%.mll.d: $(SRCDIR)/%.mll $(SRCDIR)/.merlin | $(BUILDDIR)
	@$(OCAMLDEP) -pp 'ocamllex -q -o /dev/fd/1' $< | sed "s#$(SRCDIR)/#$(BUILDDIR)/#g" > $@

$(SRCDIR)/%.ml: $(SRCDIR)/%.mll
	@echo Generating lexer $*
	@ocamllex -q $< -o $@

##################################################
## .mly files
OCAML_MENHIR_SRCS := $(wildcard $(SRCDIR)/*.mly)
OCAML_MENHIR_DEPS := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_MENHIR_SRCS))
OCAML_MENHIR_PRODUCTS := \
    $(patsubst $(SRCDIR)/%.mly,$(BUILDDIR)/%.cmo,$(OCAML_MENHIR_SRCS))  \
    $(patsubst $(SRCDIR)/%.mly,$(BUILDDIR)/%.cmi,$(OCAML_MENHIR_SRCS))  \
    $(patsubst $(SRCDIR)/%.mly,$(BUILDDIR)/%.o,$(OCAML_MENHIR_SRCS))    \
    $(patsubst $(SRCDIR)/%.mly,$(BUILDDIR)/%.cmx,$(OCAML_MENHIR_SRCS))  \
    $(OCAML_MENHIR_DEPS)
OCAML_DEPS        += $(OCAML_MENHIR_DEPS)
OCAML_PRODUCTS    += $(OCAML_MENHIR_PRODUCTS)

$(OCAML_MENHIR_DEPS): $(BUILDDIR)/%.mly.d: $(SRCDIR)/%.mly $(SRCDIR)/.merlin | $(BUILDDIR)
	@$(MENHIR) --depend --ocamldep '$(OCAMLDEP)' $< | sed -E 's#$(SRCDIR)/([A-Za-z_0-9]+\.cm[a-z]+)#$(BUILDDIR)/\1#g' > $@

# Mark Menhir's output as intermediate, so it gets deleted after a build
.INTERMEDIATE: \
  $(patsubst $(SRCDIR)/%.mly,$(SRCDIR)/%.ml,$(OCAML_MENHIR_SRCS)) \
  $(patsubst $(SRCDIR)/%.mly,$(SRCDIR)/%.mli,$(OCAML_MENHIR_SRCS))

$(SRCDIR)/%.mli $(SRCDIR)/%.ml: $(SRCDIR)/%.mly
	@echo Generating parser $*
	@menhir --infer --ocamlc '$(OCAMLC) -I $(BUILDDIR)' $<

##################################################
## .mllib files
OCAML_LIB_SRCS     := $(wildcard $(SRCDIR)/*.mllib)
OCAML_LIB_DEPS     := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_LIB_SRCS))
OCAML_LIB_PRODUCTS := \
    $(patsubst $(SRCDIR)/%.mllib,$(BUILDDIR)/%.cma,$(OCAML_LIB_SRCS))  \
    $(patsubst $(SRCDIR)/%.mllib,$(BUILDDIR)/%.cmxa,$(OCAML_LIB_SRCS)) \
    $(patsubst $(SRCDIR)/%.mllib,$(BUILDDIR)/%.a,$(OCAML_LIB_SRCS))    \
    $(OCAML_LIB_DEPS)
OCAML_DEPS         += $(OCAML_LIB_DEPS)
OCAML_PRODUCTS     += $(OCAML_LIB_PRODUCTS)

$(OCAML_LIB_DEPS): $(BUILDDIR)/%.mllib.d: $(SRCDIR)/%.mllib $(SRCDIR)/.merlin | $(BUILDDIR)
	@(echo "$(BUILDDIR)/$*.cma:" \
           $$(cat $< | sed -E 's#MOD +(.*)$$#$(BUILDDIR)/\1.cmo#' | sed -E 's#LIB +(.*)$$#$(BUILDDIR)/\1.cma#' | tr '\n' ' '); \
	  echo "$(BUILDDIR)/$*.cmxa:" \
           $$(cat $< | sed -E 's#MOD +(.*)$$#$(BUILDDIR)/\1.cmx#' | sed -E 's#LIB +(.*)$$#$(BUILDDIR)/\1.cmxa#' | tr '\n' ' ')) > $@

$(BUILDDIR)/%.cma: $(SRCDIR)/%.mllib $(SRCDIR)/.merlin | $(BUILDDIR) ocaml-tidy
	@echo Compiling library $* '(bytecode)'
	@$(OCAMLC) -a -o $@ \
	  $(shell cat $< | sed -E 's#MOD +(.*)$$#$(BUILDDIR)/\1.cmo#' | sed -E 's#LIB +(.*)$$#$(BUILDDIR)/\1.cma#' | tr '\n' ' ')

$(BUILDDIR)/%.cmxa: $(SRCDIR)/%.mllib $(SRCDIR)/.merlin | $(BUILDDIR) ocaml-tidy
	@echo Compiling library $* '(native)'
	@$(OCAMLOPT) -a -o $@ \
	  $(shell cat $< | sed -E 's#MOD +(.*)$$#$(BUILDDIR)/\1.cmx#' | sed -E 's#LIB +(.*)$$#$(BUILDDIR)/\1.cmxa#' | tr '\n' ' ')

##################################################
## .mlbin files
OCAML_BIN_SRCS     := $(wildcard $(SRCDIR)/*.mlbin)
OCAML_BIN_DEPS     := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_BIN_SRCS))
OCAML_BIN_PRODUCTS := \
    $(patsubst $(SRCDIR)/%.mlbin,$(BYTE_BINDIR)/%,$(OCAML_BIN_SRCS))   \
    $(patsubst $(SRCDIR)/%.mlbin,$(NATIVE_BINDIR)/%,$(OCAML_BIN_SRCS)) \
    $(OCAML_BIN_DEPS)
OCAML_DEPS         += $(OCAML_BIN_DEPS)
OCAML_PRODUCTS     += $(OCAML_BIN_PRODUCTS)

$(OCAML_BIN_DEPS): $(BUILDDIR)/%.mlbin.d: $(SRCDIR)/%.mlbin $(SRCDIR)/.merlin | $(BUILDDIR)
	@(echo "$(BYTE_BINDIR)/$*:" \
            $$(cat $< | sed -E 's#MOD +(.*)$$#$(BUILDDIR)/\1.cmo#' | sed -E 's#LIB +(.*)$$#$(BUILDDIR)/\1.cma#' | tr '\n' ' '); \
	  echo "$(NATIVE_BINDIR)/$*:" \
            $$(cat $< | sed -E 's#MOD +(.*)$$#$(BUILDDIR)/\1.cmx#' | sed -E 's#LIB +(.*)$$#$(BUILDDIR)/\1.cmxa#' | tr '\n' ' ')) > $@

$(BYTE_BINDIR)/%: $(SRCDIR)/%.mlbin $(SRCDIR)/.merlin | $(BYTE_BINDIR) ocaml-tidy
	@echo Linking executable '$(notdir $@)' '(bytecode)'
	@$(OCAMLC) -linkpkg \
           $(shell cat $< | sed -E 's#MOD +(.*)$$#$(BUILDDIR)/\1.cmo#' | sed -E 's#LIB +(.*)$$#$(BUILDDIR)/\1.cma#' | tr '\n' ' ') \
           -o $@

$(NATIVE_BINDIR)/%: $(SRCDIR)/%.mlbin $(SRCDIR)/.merlin | $(NATIVE_BINDIR) ocaml-tidy
	@echo Linking executable '$(notdir $@)' '(native)'
	@$(OCAMLOPT) -linkpkg \
           $(shell cat $< | sed -E 's#MOD +(.*)$$#$(BUILDDIR)/\1.cmx#' | sed -E 's#LIB +(.*)$$#$(BUILDDIR)/\1.cmxa#' | tr '\n' ' ') \
           -o $@

######################################################################
# FIXME: remove this (integrate with each of the bits above)
-include $(OCAML_DEPS)

######################################################################
# FIXME: how to handle source files being removed?
# Problem: Y.mlbin includes module X
#          X.cmo is generated from X.ml
#          binary Y is created
#          X.ml is deleted
#          X.cmo remains, and is linked into Y.mlbin successfully
#          ... until next clean, when it fails

# Maybe: for each source file, compute all the possible build products
#        and delete any .cmo,.cmi,.cmx in _build that shouldn't be there
#        and delete any $(BUILDDIR)/bin/Y files too
#        make this a PHONY order-only prereq of all ocaml recipes
#        Really: want this to run before anything else

ifndef OCAML_TIDY
OCAML_TIDY := 1
#.PHONY: ocaml-tidy
ocaml-tidy:
	@for f in $(filter-out $(sort $(OCAML_PRODUCTS)),$(shell find $(BUILDDIRS) -type f)); \
	do \
	  echo Removing $$f '(no matching source file)'; \
	  rm $$f; \
	done
endif
