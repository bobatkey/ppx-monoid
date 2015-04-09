######################################################################
# Generic OCaml build instructions; uses .merlin file to get the list
# of required ocamlfind packages.
#
# FIXME: is there any way to force a rebuild if the ocamlfind packages
# change? can ocamlfind packages be hashed?
#
# FIXME: abort if there are .ml(i) files that would be overwritten by
# ocamllex or menhir

# FIXME: ought to warn about LIB lines in .mllib files, and other
# syntax errors in the .merlin, *.mllib and *.mlbin files

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

OCAML_LIBS     := $(shell cat $(SRCDIR)/.merlin | grep ^PKG | sed -E 's/^PKG +//')
OCAML_PKGS_OPT := $(foreach lib,$(OCAML_LIBS),-package $(lib))

# FIXME: work out the PPX_BINS from this too, so we can depend on them, and have a proper way of getting the paths corrected

MERLIN_FLAGS := $(shell cat $(SRCDIR)/.merlin | grep ^FLG | cut -d' ' -f2- | grep -v '^ *-ppx')
MERLIN_PPX   :=\
  $(foreach ppx,$(shell cat $(SRCDIR)/.merlin | egrep '^FLG +-ppx +' | sed -E 's/^FLG +-ppx +//'),$(shell realpath -m --relative-to=. $(SRCDIR)/$(ppx)))

OCAMLC_FLAGS  := $(MERLIN_FLAGS) \
                 $(foreach ppx,$(MERLIN_PPX),-ppx $(ppx)) \
                 $(OCAML_PKGS_OPT)

OCAMLC        := ocamlfind ocamlc -I $(BUILDDIR) $(OCAMLC_FLAGS)
OCAMLOPT      := ocamlfind ocamlopt -I $(BUILDDIR) $(OCAMLC_FLAGS)
OCAMLDEP_OPTS := -I $(SRCDIR)/ -ml-synonym .mll -ml-synonym .mly -mli-synonym .mly
OCAMLDEP      := ocamlfind ocamldep $(OCAML_PKGS_OPT) $(OCAMLDEP_OPTS)
MENHIR        := menhir

######################################################################
$(BUILDDIR):
	@mkdir -p $@

$(BYTE_BINDIR):
	@mkdir -p $@

$(NATIVE_BINDIR):
	@mkdir -p $@

######################################################################
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

# FIXME: should probably just be OCAMLC and OCAMLC_FLAGS, which includes -I ...
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
OCAML_ML_SRCS  := $(wildcard $(SRCDIR)/*.ml)
OCAML_ML_DEPS  := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_ML_SRCS))
OCAML_PRODUCTS += \
    $(patsubst $(SRCDIR)/%.ml,$(BUILDDIR)/%.cmo,$(OCAML_ML_SRCS)) \
    $(patsubst $(SRCDIR)/%.ml,$(BUILDDIR)/%.cmi,$(OCAML_ML_SRCS)) \
    $(patsubst $(SRCDIR)/%.ml,$(BUILDDIR)/%.o,$(OCAML_ML_SRCS))   \
    $(patsubst $(SRCDIR)/%.ml,$(BUILDDIR)/%.cmx,$(OCAML_ML_SRCS)) \
    $(OCAML_ML_DEPS)

$(OCAML_ML_DEPS): $(BUILDDIR)/%.ml.d: $(SRCDIR)/%.ml $(SRCDIR)/.merlin | $(BUILDDIR)
	@$(OCAMLDEP) $< | sed "s#$(SRCDIR)/#$(BUILDDIR)/#g" > $@

-include $(OCAML_ML_DEPS)

$(BUILDDIR)/%.cmo: $(SRCDIR)/%.ml $(SRCDIR)/.merlin $(MERLIN_PPX) | $(BUILDDIR) ocaml-tidy
	@echo Compiling module $* '(bytecode)'
	@$(OCAMLC) -o $@ -c $<

$(BUILDDIR)/%.cmx: $(SRCDIR)/%.ml $(SRCDIR)/.merlin $(MERLIN_PPX) | $(BUILDDIR) ocaml-tidy
	@echo Compiling module $* '(native)'
	@$(OCAMLOPT) -o $@ -c $<

##################################################
## .mli files
OCAML_MLI_SRCS := $(wildcard $(SRCDIR)/*.mli)
OCAML_MLI_DEPS := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_MLI_SRCS))
OCAML_PRODUCTS += \
    $(patsubst $(SRCDIR)/%.mli,$(BUILDDIR)/%.cmi,$(OCAML_MLI_SRCS))  \
    $(OCAML_MLI_DEPS)

$(OCAML_MLI_DEPS): $(BUILDDIR)/%.mli.d: $(SRCDIR)/%.mli $(SRCDIR)/.merlin | $(BUILDDIR)
	@$(OCAMLDEP) $< | sed "s#$(SRCDIR)/#$(BUILDDIR)/#g" > $@

-include $(OCAML_MLI_DEPS)

$(BUILDDIR)/%.cmi: $(SRCDIR)/%.mli $(SRCDIR)/.merlin $(MERLIN_PPX) | $(BUILDDIR) ocaml-tidy
	@echo Compiling interface $*
	@$(OCAMLC) -o $@ -c $<

##################################################
## .mll files
OCAML_LEX_SRCS := $(wildcard $(SRCDIR)/*.mll)
OCAML_LEX_DEPS := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_LEX_SRCS))
OCAML_PRODUCTS += \
    $(patsubst $(SRCDIR)/%.mll,$(BUILDDIR)/%.cmo,$(OCAML_LEX_SRCS))  \
    $(patsubst $(SRCDIR)/%.mll,$(BUILDDIR)/%.cmi,$(OCAML_LEX_SRCS))  \
    $(patsubst $(SRCDIR)/%.mll,$(BUILDDIR)/%.o,$(OCAML_LEX_SRCS))    \
    $(patsubst $(SRCDIR)/%.mll,$(BUILDDIR)/%.cmx,$(OCAML_LEX_SRCS))  \
    $(OCAML_LEX_DEPS)

$(OCAML_LEX_DEPS): $(BUILDDIR)/%.mll.d: $(SRCDIR)/%.mll $(SRCDIR)/.merlin | $(BUILDDIR)
	@$(OCAMLDEP) -pp 'ocamllex -q -o /dev/fd/1' $< | sed "s#$(SRCDIR)/#$(BUILDDIR)/#g" > $@

-include $(OCAML_LEX_DEPS)

$(SRCDIR)/%.ml: $(SRCDIR)/%.mll
	@echo Generating lexer $*
	@ocamllex -q $< -o $@

##################################################
## .mly files
OCAML_MENHIR_SRCS := $(wildcard $(SRCDIR)/*.mly)
OCAML_MENHIR_DEPS := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_MENHIR_SRCS))
OCAML_PRODUCTS    += \
    $(patsubst $(SRCDIR)/%.mly,$(BUILDDIR)/%.cmo,$(OCAML_MENHIR_SRCS))  \
    $(patsubst $(SRCDIR)/%.mly,$(BUILDDIR)/%.cmi,$(OCAML_MENHIR_SRCS))  \
    $(patsubst $(SRCDIR)/%.mly,$(BUILDDIR)/%.o,$(OCAML_MENHIR_SRCS))    \
    $(patsubst $(SRCDIR)/%.mly,$(BUILDDIR)/%.cmx,$(OCAML_MENHIR_SRCS))  \
    $(OCAML_MENHIR_DEPS)

$(OCAML_MENHIR_DEPS): $(BUILDDIR)/%.mly.d: $(SRCDIR)/%.mly $(SRCDIR)/.merlin | $(BUILDDIR)
	@$(MENHIR) --depend --ocamldep '$(OCAMLDEP)' $< | sed -E 's#$(SRCDIR)/([A-Za-z_0-9]+\.cm[a-z]+)#$(BUILDDIR)/\1#g' > $@

-include $(OCAML_MENHIR_DEPS)

# Mark Menhir's output as intermediate, so it gets deleted after a build
.INTERMEDIATE: \
  $(patsubst $(SRCDIR)/%.mly,$(SRCDIR)/%.ml,$(OCAML_MENHIR_SRCS)) \
  $(patsubst $(SRCDIR)/%.mly,$(SRCDIR)/%.mli,$(OCAML_MENHIR_SRCS))

$(SRCDIR)/%.mli $(SRCDIR)/%.ml: $(SRCDIR)/%.mly
	@echo Generating parser $*
	@menhir --infer --ocamlc '$(OCAMLC)' $<

##################################################
## .mllib files
OCAML_LIB_SRCS := $(wildcard $(SRCDIR)/*.mllib)
OCAML_LIB_DEPS := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_LIB_SRCS))
OCAML_PRODUCTS += \
    $(patsubst $(SRCDIR)/%.mllib,$(BUILDDIR)/%.cma,$(OCAML_LIB_SRCS))  \
    $(patsubst $(SRCDIR)/%.mllib,$(BUILDDIR)/%.cmxa,$(OCAML_LIB_SRCS)) \
    $(patsubst $(SRCDIR)/%.mllib,$(BUILDDIR)/%.a,$(OCAML_LIB_SRCS))    \
    $(OCAML_LIB_DEPS)

# FIXME: use private local variable to add linker options
$(OCAML_LIB_DEPS): $(BUILDDIR)/%.mllib.d: $(SRCDIR)/%.mllib $(SRCDIR)/.merlin | $(BUILDDIR)
	@(echo "$(BUILDDIR)/$*.cma:" \
           $$(cat $< | sed -E 's#MOD +(.*)$$#$(BUILDDIR)/\1.cmo#' | tr '\n' ' '); \
	  echo "$(BUILDDIR)/$*.cmxa:" \
           $$(cat $< | sed -E 's#MOD +(.*)$$#$(BUILDDIR)/\1.cmx#' | tr '\n' ' ')) > $@

-include $(OCAML_LIB_DEPS)

$(BUILDDIR)/%.cma: $(SRCDIR)/%.mllib $(SRCDIR)/.merlin | $(BUILDDIR) ocaml-tidy
	@echo Compiling library $* '(bytecode)'
	@$(OCAMLC) -a $(filter %.cmo,$+) -o $@

$(BUILDDIR)/%.cmxa: $(SRCDIR)/%.mllib $(SRCDIR)/.merlin | $(BUILDDIR) ocaml-tidy
	@echo Compiling library $* '(native)'
	@$(OCAMLOPT) -a $(filter %.cmx,$+) -o $@

##################################################
## .mlbin files
OCAML_BIN_SRCS := $(wildcard $(SRCDIR)/*.mlbin)
OCAML_BIN_DEPS := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_BIN_SRCS))
OCAML_PRODUCTS += \
    $(patsubst $(SRCDIR)/%.mlbin,$(BYTE_BINDIR)/%,$(OCAML_BIN_SRCS))   \
    $(patsubst $(SRCDIR)/%.mlbin,$(NATIVE_BINDIR)/%,$(OCAML_BIN_SRCS)) \
    $(OCAML_BIN_DEPS)

# FIXME: use private local variable to add linker options
$(OCAML_BIN_DEPS): $(BUILDDIR)/%.mlbin.d: $(SRCDIR)/%.mlbin $(SRCDIR)/.merlin | $(BUILDDIR)
	@(echo "$(BYTE_BINDIR)/$*:" \
            $$(cat $< | sed -E 's#MOD +(.*)$$#$(BUILDDIR)/\1.cmo#' | sed -E 's#LIB +(.*)$$#$(BUILDDIR)/\1.cma#' | tr '\n' ' '); \
	  echo "$(NATIVE_BINDIR)/$*:" \
            $$(cat $< | sed -E 's#MOD +(.*)$$#$(BUILDDIR)/\1.cmx#' | sed -E 's#LIB +(.*)$$#$(BUILDDIR)/\1.cmxa#' | tr '\n' ' ')) > $@

-include $(OCAML_BIN_DEPS)

$(BYTE_BINDIR)/%: $(SRCDIR)/%.mlbin $(SRCDIR)/.merlin | $(BYTE_BINDIR) ocaml-tidy
	@echo Linking executable '$(notdir $@)' '(bytecode)'
	@$(OCAMLC) -linkpkg $(filter %.cmo %.cma,$+) -o $@

$(NATIVE_BINDIR)/%: $(SRCDIR)/%.mlbin $(SRCDIR)/.merlin | $(NATIVE_BINDIR) ocaml-tidy
	@echo Linking executable '$(notdir $@)' '(native)'
	@$(OCAMLOPT) -linkpkg $(filter %.cmx %.cmxa,$+) -o $@

# $(BUILDDIR)/%.js: $(BYTE_BINDIR)/%
# 	@echo Compiling javascript $*
# 	@js_of_ocaml --opt 2 $< -o $@

######################################################################
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
