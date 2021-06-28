##############################################################################
##                                                                          ##
##                            GPR2 PROJECT LIBRARY                          ##
##                                                                          ##
##          Copyright (C) 2016-2021, Free Software Foundation, Inc.         ##
##                                                                          ##
## This library is free software;  you can redistribute it and/or modify it ##
## under terms of the  GNU General Public License  as published by the Free ##
## Software  Foundation;  either version 3,  or (at your  option) any later ##
## version. This library is distributed in the hope that it will be useful, ##
## but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN# ##
## TABILITY or FITNESS FOR A PARTICULAR PURPOSE.                            ##
##                                                                          ##
## As a special exception under Section 7 of GPL version 3, you are granted ##
## additional permissions described in the GCC Runtime Library Exception,   ##
## version 3.1, as published by the Free Software Foundation.               ##
##                                                                          ##
## You should have received a copy of the GNU General Public License and    ##
## a copy of the GCC Runtime Library Exception along with this program;     ##
## see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    ##
## <http://www.gnu.org/licenses/>.                                          ##
##                                                                          ##
##############################################################################

# Makefile targets
# ----------------
#
# Setup:                   make [VAR=VALUE] setup (see below)
# Build libgpr2:           make
# Install libgpr2:         make install

# Variables which can be set:
#
#   prefix        : root install directory
#   ENABLE_SHARED : yes / no (or empty)
#   BUILD         : debug release
#   PROCESSORS    : nb parallel compilations (0 to use all cores)
#   PROFILER      : Include gprof support instrumentation (yes / no)
#   TARGET        : target triplet for cross-compilation

HOST    = $(shell gcc -dumpmachine)
TARGET := $(shell gcc -dumpmachine)

prefix	      := $(dir $(shell which gnatls))..
BUILD         = release
PROCESSORS    = 0
PROFILER      = no
BUILD_DIR     =
SOURCE_DIR    := $(shell dirname "$(MAKEFILE_LIST)")
ENABLE_SHARED := $(shell gprbuild $(GTARGET) -c -q -p \
	-P$(MAKEPREFIX)config/test_shared 2>/dev/null && echo "yes")
GPRINSTALL    = gprinstall

# Whether to use gpr<name> or the alternate gpr2<name> tools names
GPR2_TOOLS_PREFIX=gpr

# Whether to enable coverage (empty for no, any other value for yes)
COVERAGE=

# Whether we want to force a (re-)generation of the langkit parser.
# Set this to "force" to regenerate the parser.
FORCE_PARSER_GEN=

# check for out-of-tree build
ifeq ($(SOURCE_DIR),.)
RBD=
GPR2=gpr2.gpr
GPR2TOOLS=gpr2-tools.gpr
GPR2KB=src/kb/collect_kb.gpr
GPR2KBDIR=src/kb/gprconfig_kb
MAKEPREFIX=
LANGKIT_GENERATED_SRC=langkit/build
else
ifeq ($(COVERAGE),)
RBD=--relocate-build-tree
else
RBD=
endif
GPR2=$(SOURCE_DIR)/gpr2.gpr
GPR2TOOLS=$(SOURCE_DIR)/gpr2-tools.gpr
GPR2KB=$(SOURCE_DIR)/src/kb/collect_kb.gpr
GPR2KBDIR=$(SOURCE_DIR)/src/kb/gprconfig_kb
MAKEPREFIX=$(SOURCE_DIR)/
LANGKIT_GENERATED_SRC=$(shell pwd)/langkit/build
endif

# Load current setup if any
-include makefile.setup

# target options for cross-build
ifeq ($(HOST),$(TARGET))
GTARGET=
else
GTARGET=--target=$(TARGET)
endif

ifeq ($(ENABLE_SHARED)$(COVERAGE), yes)
   LIBGPR2_TYPES=static relocatable static-pic
else
   LIBGPR2_TYPES=static
endif

# Used to pass extra options to GPRBUILD, like -d for instance
GPRBUILD_OPTIONS=

ifeq ($(COVERAGE),)
   COVERAGE_BUILD_FLAGS=
else
   override BUILD=debug
   COVERAGE_BUILD_FLAGS= \
           --implicit-with=gnatcov_rts_full \
           --src-subdirs=gnatcov-instr
   COVERAGE_INSTR_FLAGS= -XBUILD=${BUILD} \
           -XLANGKIT_GENERATED_SRC=${LANGKIT_GENERATED_SRC} \
           -XLIBRARY_TYPE=static -XXMLADA_BUILD=static \
           -XLANGKIT_SUPPORT_BUILD=static
   COVERAGE_INSTR=gnatcov instrument --level $(LEVEL) --dump-trigger=atexit \
        $(COVERAGE_INSTR_FLAGS)
endif

GPR_OPTIONS=$(GTARGET) $(RBD) -XBUILD=${BUILD} \
	-XGPR2_TOOLS_PREFIX=${GPR2_TOOLS_PREFIX} \
	-aP ${LANGKIT_GENERATED_SRC}/lib/gnat \
	-XLANGKIT_GENERATED_SRC=${LANGKIT_GENERATED_SRC}

BUILDER=gprbuild -p -m -j${PROCESSORS} ${GPR_OPTIONS} ${GPRBUILD_OPTIONS} \
             -XPROFILER=${PROFILER} ${COVERAGE_BUILD_FLAGS}
INSTALLER=${GPRINSTALL} -p -f ${GPR_OPTIONS} --prefix=${prefix}
CLEANER=gprclean -eL -p $(RBD)
UNINSTALLER=$(INSTALLER) -p -f --uninstall

.PHONY: force

#########
# build #
#########

all: ${LIBGPR2_TYPES:%=build-%} build-tools

# Knowledge base
src/kb/config.kb: $(wildcard $(GPR2KBDIR)/**/*)
	gprbuild -p $(GPR2KB)
	$(SOURCE_DIR)/src/kb/collect_kb -o $(SOURCE_DIR)/src/kb/config.kb \
		$(GPR2KBDIR)

# Langkit parser (GPR + Ada support)
langkit/build: $(wildcard langkit/language/**/*.py) $(FORCE_PARSER_GEN)
	$(MAKE) -C ${SOURCE_DIR}/langkit setup DEST=$(shell pwd)/langkit/build
	touch langkit/build

# Libgpr2
build-%: src/kb/config.kb langkit/build
ifeq ($(COVERAGE),)
	$(BUILDER) -XLIBRARY_TYPE=$* -XXMLADA_BUILD=$* \
		-XLANGKIT_SUPPORT_BUILD=$* $(GPR2)
else
	echo "gpr2 library built from gpr2-tools in coverage mode"
endif

# Gpr2 tools
build-tools: build-static coverage-instrument
	$(BUILDER) -XLIBRARY_TYPE=static -XXMLADA_BUILD=static \
		-XLANGKIT_SUPPORT_BUILD=static $(GPR2TOOLS)

# Gnatcov instrumentation
coverage-instrument:
ifneq ($(COVERAGE),)
	# Remove artifacts from previous instrumentations, so that stale units
	# that are not overriden by new ones don't get in our way.
	rm -rf $(SOURCE_DIR)/.build/$(BUILD)/obj-*/*gnatcov-instr
	mkdir -p $(SOURCE_DIR)/.build/$(BUILD)

	$(COVERAGE_INSTR) -P $(GPR2TOOLS)
endif

###########
# Install #
###########

uninstall:
ifneq (,$(wildcard $(prefix)/share/gpr/manifests/gpr2))
	$(UNINSTALLER) $(GPR2)
endif
ifneq (,$(wildcard $(prefix)/share/gpr/manifests/gpr2-tools))
	$(UNINSTALLER) $(GPR2TOOLS)
endif

install: uninstall ${LIBGPR2_TYPES:%=install-%} install-tools

install-%:
	$(INSTALLER) -XLIBRARY_TYPE=$* -XXMLADA_BUILD=$* \
		-XLANGKIT_SUPPORT_BUILD=$* \
		--build-name=$* --build-var=LIBRARY_TYPE \
		--build-var=GPR2_BUILD $(GPR2)

install-tools:
	$(INSTALLER) -XLIBRARY_TYPE=static -XXMLADA_BUILD=static \
		-XLANGKIT_SUPPORT_BUILD=static --build-name=static \
		--mode=usage $(GPR2TOOLS)

ifneq ($(COVERAGE),)
install-instrumented: install-static
	mkdir -p $(prefix)/share/gpr2/sids || true
	# copy gpr2 & gpr2-tools sid files
	cp $(SOURCE_DIR)/.build/$(BUILD)/obj-*/*.sid $(prefix)/share/gpr2/sids/
	# exclude generated code from test coverage statistics
	-rm $(prefix)/share/gpr2/sids/gpr_parser*
	# copy instrumented gpr2 source files
	cp $(SOURCE_DIR)/.build/$(BUILD)/obj-static/gpr2-gnatcov-instr/*.ad? \
		$(prefix)/include/gpr2.static/.
	# copy instrumented gpr2 ali files
	cp $(SOURCE_DIR)/.build/$(BUILD)/lib-static/*.ali \
		$(prefix)/lib/gpr2.static/.
endif

#########
# setup #
#########

.SILENT: setup setup2

setup:
	echo "prefix=$(prefix)" > makefile.setup
	echo "ENABLE_SHARED=$(ENABLE_SHARED)" >> makefile.setup
	echo "BUILD=$(BUILD)" >> makefile.setup
	echo "PROCESSORS=$(PROCESSORS)" >> makefile.setup
	echo "PROFILER=$(PROFILER)" >> makefile.setup
	echo "TARGET=$(TARGET)" >> makefile.setup
	echo "SOURCE_DIR=$(SOURCE_DIR)" >> makefile.setup
	echo "GPR2KBDIR=$(GPR2KBDIR)" >> makefile.setup
	echo "GPR2_TOOLS_PREFIX=$(GPR2_TOOLS_PREFIX)" >> makefile.setup

setup2: setup
	echo "GPRINSTALL=.build/$(BUILD)/obj-tools/$(GPR2_TOOLS_PREFIX)install" >> makefile.setup

###########
# Cleanup #
###########

distclean: clean
	rm -rf .build
	rm -f makefile.setup

clean: clean-tools ${LIBGPR2_TYPES:%=clean-%}
	rm -f src/kb/collect_kb
	rm -f src/kb/config.kb
	rm -rf src/kb/obj
	make -C langkit clean

clean-%:
	-$(CLEANER) -XLIBRARY_TYPE=$* -XXMLADA_BUILD=$* -P $(GPR2)

clean-tools:
	-$(CLEANER) -P $(GPR2TOOLS)
