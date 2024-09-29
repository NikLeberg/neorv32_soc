include $(PROJ_ROOT)/scripts/makefile.def

$(info Running main Makefile.)

# Define bash as the shell to use for sub-shells. The environment variable
# $BASH_ENV points to the .env file containing aliases of commands for running
# in docker containers. These aliases can then be used in recipies.
SHELL = BASH_ENV=../.devcontainer/.env /bin/bash

# Helper variables.
tab := $(shell echo -e "\t")

# Glob relevant files of all libraries.
VHDL_FILES = $(foreach lib_path,$(LIB_PATHS),$(shell find $(lib_path) -wholename '**/*.vhd*'))
PSL_FILES  = $(foreach lib_path,$(LIB_PATHS),$(shell find $(lib_path) -wholename '**/*.psl'))

# First rule to catch make invocation with no target that "builds" first rule.
.PHONY: help
help:
	@echo "A set of Makefiles for synthesizing, testing and validating VHDL projects with"
	@echo "automatic dependency resolution. (c) MIT 2023 Niklaus Leuenberger"
	@echo "To compile, type  'make <tool> <library>.<design_unit>'."
	@echo "To simulate, type 'make <tool> <library>.<design_unit> sim'."
	@echo "Available tools:"
	@echo "$(tab)questa - compiling and simulating with Intel QuestaSim / ModelSim"
	@echo "$(tab)oss    - simulating with open source GHDL"
	@echo "$(tab)nvc    - simulating with open source NVC"
	@echo "Definitions from 'makefile.def':"
	@echo "$(tab)LIBS:          $(LIBS)"
	@echo "$(tab)LIB_PATHS:     $(LIB_PATHS)"
	@echo "$(tab)IGNORED_FILES: $(IGNORED_FILES)"
	@echo "$(tab)TOP:           $(TOP)"

# Evaluate dependencies of relevant library files on change.
DEP_PARSE_SCRIPT := $(PROJ_ROOT)/scripts/dep_parse.py
deps.d: $(DEP_PARSE_SCRIPT) $(VHDL_FILES) $(PSL_FILES)
	@python $(DEP_PARSE_SCRIPT)
MAKE_CLEAN += deps.d

-include last.tool
LAST_TOOL ?=
MAKE_CLEAN += last.tool

.PHONY: questa
questa: deps.d questa_tool
	@questa_make -f $(PROJ_ROOT)/scripts/makefile.questa $(MAKECMDGOALS) PROJ_ROOT=$(PROJ_ROOT)

.PHONY: oss
oss: deps.d oss_tool
	@oss_make -f $(PROJ_ROOT)/scripts/makefile.oss $(MAKECMDGOALS) PROJ_ROOT=$(PROJ_ROOT)

.PHONY: nvc
nvc: deps.d nvc_tool
	@nvc_make -f $(PROJ_ROOT)/scripts/makefile.nvc $(MAKECMDGOALS) PROJ_ROOT=$(PROJ_ROOT)

.PHONY: quartus
quartus: deps.d quartus_tool
	@quartus_make -f $(PROJ_ROOT)/scripts/makefile.quartus $(MAKECMDGOALS) PROJ_ROOT=$(PROJ_ROOT)

%_tool:
	@test -z "$(LAST_TOOL)" || test "$(LAST_TOOL)" == "$*"
	@echo "LAST_TOOL=$*" > last.tool

# Do nothing targets, they are defined in the tool makefiles.
.PHONY: sim test
sim test:
	@

.PHONY: clean
clean: $(LAST_TOOL)_clean
	@rm -f $(MAKE_CLEAN)
	@rm -rf du/
	@rm -rf obj/

_clean:
	@

%_clean:
	@$*_make -f $(PROJ_ROOT)/scripts/makefile.$* clean

# Catch-All target. Actual work should be done in sub-makes.
%:
	@
