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
# syntax errors in the .merlin, *.mllib and *.mlbin files. In general,
# a checker for .merlin files' consistency.
#
# FIXME: Javascript output?
#
# FIXME: when to include -no-alias-deps? In general, how to use module
# aliases effectively for building libraries?

# FIXME: how about build wrappers for ocamlfind ocamlc etc, that read
# the .merlin file to get build flags?

######################################################################
ifndef SRCDIR
$(error SRCDIR must be set)
endif

# FIXME: Could have _build/$(SRCDIR)/ ??
BUILDDIR := $(SRCDIR)/_build

ifndef BUILDDIRS
BUILDDIRS := $(BUILDDIR)
else
BUILDDIRS := $(BUILDDIRS) $(BUILDDIR)
endif

BYTE_BINDIR    := $(BUILDDIR)/byte_bin
NATIVE_BINDIR  := $(BUILDDIR)/native_bin

######################################################################
# OCAML_PRODUCTS contains that could possibly be generated from the
# current source files in all source directories
ifndef OCAML_PRODUCTS
OCAML_PRODUCTS :=
endif

######################################################################
# Gather compiler options from the .merlin file

# FIXME: if the .merlin file doesn't exist then use some sensible
# defaults

# OCAML_LIBS     := $(shell cat $(SRCDIR)/.merlin | grep ^PKG | sed -E 's/^PKG +//')
# OCAML_PKGS_OPT := $(foreach lib,$(OCAML_LIBS),-package $(lib))

# MERLIN_FLAGS := $(shell cat $(SRCDIR)/.merlin | grep ^FLG | cut -d' ' -f2- | grep -v '^ *-ppx')
# PPX_BINARIES :=\
#   $(foreach ppx,$(shell cat $(SRCDIR)/.merlin | egrep '^FLG +-ppx +' | sed -E 's/^FLG +-ppx +//'),$(shell realpath -m --relative-to=. $(SRCDIR)/$(ppx)))

# MERLIN_BINDIRS := $(shell cat $(SRCDIR)/.merlin | grep ^B | cut -d ' ' -f2- | grep -v '_build')
# BINDIRS_OPT    := -I $(BUILDDIR) $(foreach dir,$(MERLIN_BINDIRS),-I $(shell realpath -m --relative-to=. $(SRCDIR)/$(dir)))

# MERLIN_SRCDIRS := $(shell cat $(SRCDIR)/.merlin | grep ^S | cut -d ' ' -f2- | grep -v '\.')
# SRCDIRS_OPT    := -I $(SRCDIR) $(foreach dir,$(MERLIN_SRCDIRS),-I $(shell realpath -m --relative-to=. $(SRCDIR)/$(dir)))

# OCAMLC_FLAGS  := $(MERLIN_FLAGS) \
#                  $(foreach ppx,$(PPX_BINARIES),-ppx $(ppx)) \
#                  -no-alias-deps

# FIXME: this is really slow... maybe need to make an ocamlfind
# package? then use ocamlfind build-support/of_merlin -pkgs
# $(SRCDIR)/.merlin

OCAMLDEP_FLAGS := $(shell build-support/of_merlin -ocamldep-flags $(SRCDIR)/.merlin)
OCAMLC_FLAGS   := $(shell build-support/of_merlin -ocamlc-flags $(SRCDIR)/.merlin) -no-alias-deps
PPX_BINARIES   := $(shell build-support/of_merlin -ppx-bins $(SRCDIR)/.merlin)
SRCDIRS_OPT    := $(shell build-support/of_merlin -src-dirs $(SRCDIR)/.merlin)
BINDIRS_OPT    := $(shell build-support/of_merlin -bin-dirs $(SRCDIR)/.merlin)

# or ocamlfind build-support/run $(SRCDIR)/.merlin ocamlc ...
# or adjust ocamlfind to take an options file...
# and write a new version of mlbindep
# .. only problem: still need to extract PPX_BINARIES from the .merlin file... (not sure this works right anyway...)

######################################################################
# Construct command lines for all the compiler executables to be used

# FIXME: weird bug in ocamlfind: if -only-show is used it seems to run
# these commands and also output the command line. If there are .cma
# or .cmxa files mentioned (e.g., via -linkpkg), then it will generate
# an a.out file

OCAMLC        := ocamlfind ocamlc   $(BINDIRS_OPT) $(OCAMLC_FLAGS)
OCAMLOPT      := ocamlfind ocamlopt $(BINDIRS_OPT) $(OCAMLC_FLAGS)
OCAMLC_LINK   := ocamlfind ocamlc   $(BINDIRS_OPT) $(OCAMLC_FLAGS) -linkpkg
OCAMLOPT_LINK := ocamlfind ocamlopt $(BINDIRS_OPT) $(OCAMLC_FLAGS) -linkpkg
OCAMLDEP      := ocamlfind ocamldep $(SRCDIRS_OPT) $(OCAMLDEP_FLAGS) -ml-synonym .mll -ml-synonym .mly -mli-synonym .mly
MLBINDEP      := ocaml build-support/mlbindep.ml $(SRCDIRS_OPT)

######################################################################
$(BUILDDIR):
	@mkdir -p $@

$(BYTE_BINDIR):
	@mkdir -p $@

$(NATIVE_BINDIR):
	@mkdir -p $@

######################################################################
## .ml files
OCAML_ML_SRCS  := $(wildcard $(SRCDIR)/*.ml)
OCAML_ML_DEPS  := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_ML_SRCS))
OCAML_PRODUCTS += \
    $(patsubst $(SRCDIR)/%.ml,$(BUILDDIR)/%.cmo,$(OCAML_ML_SRCS)) \
    $(patsubst $(SRCDIR)/%.ml,$(BUILDDIR)/%.cmi,$(OCAML_ML_SRCS)) \
    $(patsubst $(SRCDIR)/%.ml,$(BUILDDIR)/%.o,$(OCAML_ML_SRCS))   \
    $(patsubst $(SRCDIR)/%.ml,$(BUILDDIR)/%.cmx,$(OCAML_ML_SRCS)) \
    $(OCAML_ML_DEPS)

$(BUILDDIR)/%.ml.d: private OCAMLDEP := $(OCAMLDEP)
$(BUILDDIR)/%.ml.d: $(SRCDIR)/%.ml $(SRCDIR)/.merlin | $(BUILDDIR)
	@echo Generating dependencies for $<
	@$(OCAMLDEP) $< | sed -E "s#([A-Za-z_0-9]+.cm)#_build/\1#g" > $@

-include $(OCAML_ML_DEPS)

$(BUILDDIR)/%.cmo: private OCAMLC := $(OCAMLC)
$(BUILDDIR)/%.cmo: $(SRCDIR)/%.ml $(SRCDIR)/.merlin $(PPX_BINARIES) | $(BUILDDIR) ocaml-tidy
	@echo Compiling module $* '(bytecode)'
	@$(OCAMLC) -o $@ -c $<

$(BUILDDIR)/%.cmx: private OCAMLOPT := $(OCAMLOPT)
$(BUILDDIR)/%.cmx: $(SRCDIR)/%.ml $(SRCDIR)/.merlin $(PPX_BINARIES) | $(BUILDDIR) ocaml-tidy
	@echo Compiling module $* '(native)'
	@$(OCAMLOPT) -o $@ -c $<

######################################################################
## .mli files
OCAML_MLI_SRCS := $(wildcard $(SRCDIR)/*.mli)
OCAML_MLI_DEPS := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_MLI_SRCS))
OCAML_PRODUCTS += \
    $(patsubst $(SRCDIR)/%.mli,$(BUILDDIR)/%.cmi,$(OCAML_MLI_SRCS))  \
    $(OCAML_MLI_DEPS)

$(BUILDDIR)/%.mli.d: private $(OCAMLDEP) := $(OCAMLDEP)
$(BUILDDIR)/%.mli.d: $(SRCDIR)/%.mli $(SRCDIR)/.merlin | $(BUILDDIR)
	@echo Generating dependencies for $<
	@$(OCAMLDEP) $< | sed -E "s#([A-Za-z_0-9]+.cm)#_build/\1#g" > $@

-include $(OCAML_MLI_DEPS)

$(BUILDDIR)/%.cmi: private OCAMLC := $(OCAMLC)
$(BUILDDIR)/%.cmi: $(SRCDIR)/%.mli $(SRCDIR)/.merlin $(PPX_BINARIES) | $(BUILDDIR) ocaml-tidy
	@echo Compiling interface $*
	@$(OCAMLC) -o $@ -c $<

######################################################################
## .mll files
OCAML_LEX_SRCS := $(wildcard $(SRCDIR)/*.mll)
OCAML_LEX_DEPS := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_LEX_SRCS))
OCAML_PRODUCTS += \
    $(patsubst $(SRCDIR)/%.mll,$(BUILDDIR)/%.cmo,$(OCAML_LEX_SRCS))  \
    $(patsubst $(SRCDIR)/%.mll,$(BUILDDIR)/%.cmi,$(OCAML_LEX_SRCS))  \
    $(patsubst $(SRCDIR)/%.mll,$(BUILDDIR)/%.o,$(OCAML_LEX_SRCS))    \
    $(patsubst $(SRCDIR)/%.mll,$(BUILDDIR)/%.cmx,$(OCAML_LEX_SRCS))  \
    $(OCAML_LEX_DEPS)

# FIXME: error if there is a name.ml for any name.mll

$(BUILDDIR)/%.mll.d: private OCAMLDEP := $(OCAMLDEP)
$(BUILDDIR)/%.mll.d: $(SRCDIR)/%.mll $(SRCDIR)/.merlin | $(BUILDDIR)
	@$(OCAMLDEP) -pp 'ocamllex -q -o /dev/fd/1' $< | sed -E "s#([A-Za-z_0-9]+.cm)#_build/\1#g" > $@

-include $(OCAML_LEX_DEPS)

$(SRCDIR)/%.ml: $(SRCDIR)/%.mll
	@echo Generating lexer $*
	@ocamllex -q $< -o $@

######################################################################
## .mly files, using menhir
OCAML_MENHIR_SRCS := $(wildcard $(SRCDIR)/*.mly)
OCAML_MENHIR_DEPS := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_MENHIR_SRCS))
OCAML_PRODUCTS    += \
    $(patsubst $(SRCDIR)/%.mly,$(BUILDDIR)/%.cmo,$(OCAML_MENHIR_SRCS))  \
    $(patsubst $(SRCDIR)/%.mly,$(BUILDDIR)/%.cmi,$(OCAML_MENHIR_SRCS))  \
    $(patsubst $(SRCDIR)/%.mly,$(BUILDDIR)/%.o,$(OCAML_MENHIR_SRCS))    \
    $(patsubst $(SRCDIR)/%.mly,$(BUILDDIR)/%.cmx,$(OCAML_MENHIR_SRCS))  \
    $(OCAML_MENHIR_DEPS)

# FIXME: error if there is a name.mli or name.ml for any name.mly

$(BUILDDIR)/%.mly.d: private OCAMLDEP := $(OCAMLDEP)
$(BUILDDIR)/%.mly.d: $(SRCDIR)/%.mly $(SRCDIR)/.merlin | $(BUILDDIR)
	@menhir --depend --ocamldep '$(OCAMLDEP)' $< | sed -E "s#([A-Za-z_0-9]+.cm)#_build/\1#g" > $@

-include $(OCAML_MENHIR_DEPS)

# Mark Menhir's output as intermediate, so it gets deleted after a build
.INTERMEDIATE: \
  $(patsubst $(SRCDIR)/%.mly,$(SRCDIR)/%.ml,$(OCAML_MENHIR_SRCS)) \
  $(patsubst $(SRCDIR)/%.mly,$(SRCDIR)/%.mli,$(OCAML_MENHIR_SRCS))

$(SRCDIR)/%.mli $(SRCDIR)/%.ml: private OCAMLC = $(OCAMLC)
$(SRCDIR)/%.mli $(SRCDIR)/%.ml: $(SRCDIR)/%.mly $(PPX_BINARIES)
	@echo Generating parser $*
	@menhir --infer --ocamlc '$(OCAMLC)' $<

######################################################################
## .mllib files
OCAML_LIB_SRCS := $(wildcard $(SRCDIR)/*.mllib)
OCAML_LIB_DEPS := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_LIB_SRCS))
OCAML_PRODUCTS += \
    $(patsubst $(SRCDIR)/%.mllib,$(BUILDDIR)/%.cma,$(OCAML_LIB_SRCS))  \
    $(patsubst $(SRCDIR)/%.mllib,$(BUILDDIR)/%.cmxa,$(OCAML_LIB_SRCS)) \
    $(patsubst $(SRCDIR)/%.mllib,$(BUILDDIR)/%.a,$(OCAML_LIB_SRCS))    \
    $(OCAML_LIB_DEPS)

# FIXME: use private target-specific variable to add linker options
# FIXME: what about lower-case .cmo files?
$(BUILDDIR)/%.mllib.d: private MLBINDEP := $(MLBINDEP)
$(BUILDDIR)/%.mllib.d: $(SRCDIR)/%.mllib $(SRCDIR)/.merlin | $(BUILDDIR)
	@echo Generating dependencies for $<
	@$(MLBINDEP) $< > $@

-include $(OCAML_LIB_DEPS)

$(BUILDDIR)/%.cma: private OCAMLC := $(OCAMLC)
$(BUILDDIR)/%.cma: $(SRCDIR)/%.mllib $(SRCDIR)/.merlin | $(BUILDDIR) ocaml-tidy
	@echo Compiling library $* '(bytecode)'
	@$(OCAMLC) -a $(filter %.cmo,$+) -o $@

$(BUILDDIR)/%.cmxa: private OCAMLOPT := $(OCAMLOPT)
$(BUILDDIR)/%.cmxa: $(SRCDIR)/%.mllib $(SRCDIR)/.merlin | $(BUILDDIR) ocaml-tidy
	@echo Compiling library $* '(native)'
	@$(OCAMLOPT) -a $(filter %.cmx,$+) -o $@

######################################################################
## .mlbin files
OCAML_BIN_SRCS := $(wildcard $(SRCDIR)/*.mlbin)
OCAML_BIN_DEPS := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%.d,$(OCAML_BIN_SRCS))
OCAML_PRODUCTS += \
    $(patsubst $(SRCDIR)/%.mlbin,$(BYTE_BINDIR)/%,$(OCAML_BIN_SRCS))   \
    $(patsubst $(SRCDIR)/%.mlbin,$(NATIVE_BINDIR)/%,$(OCAML_BIN_SRCS)) \
    $(OCAML_BIN_DEPS)

# FIXME: use private local variable to add linker options
$(BUILDDIR)/%.mlbin.d: private MLBINDEP := $(MLBINDEP)
$(BUILDDIR)/%.mlbin.d: $(SRCDIR)/%.mlbin $(SRCDIR)/.merlin | $(BUILDDIR)
	@echo Generating dependencies for $<
	@$(MLBINDEP) $< > $@

-include $(OCAML_BIN_DEPS)

$(BYTE_BINDIR)/%: private OCAMLC_LINK := $(OCAMLC_LINK)
$(BYTE_BINDIR)/%: $(SRCDIR)/%.mlbin $(SRCDIR)/.merlin | $(BYTE_BINDIR) ocaml-tidy
	@echo Linking executable '$(notdir $@)' '(bytecode)'
	@$(OCAMLC_LINK) $(filter %.cmo %.cma,$+) -o $@

$(NATIVE_BINDIR)/%: private OCAMLOPT_LINK := $(OCAMLOPT_LINK)
$(NATIVE_BINDIR)/%: $(SRCDIR)/%.mlbin $(SRCDIR)/.merlin | $(NATIVE_BINDIR) ocaml-tidy
	@echo Linking executable '$(notdir $@)' '(native)'
	@$(OCAMLOPT_LINK) $(filter %.cmx %.cmxa,$+) -o $@

# $(BUILDDIR)/%.js: $(BYTE_BINDIR)/%
# 	@echo Compiling javascript $*
# 	@js_of_ocaml --opt 2 $< -o $@

######################################################################
ifndef OCAML_TIDY
OCAML_TIDY := 1
ocaml-tidy:
	@for f in $(filter-out $(sort $(OCAML_PRODUCTS)),$(shell find $(BUILDDIRS) -type f)); \
	do \
	  echo Removing $$f '(no matching source file)'; \
	  rm $$f; \
	done
endif
