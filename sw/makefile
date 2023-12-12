# Define bash as the shell to use for sub-shells. The flag --rcfile is set to
# the .env file containing aliases of commands for running in docker containers.
SHELL       = /bin/bash
.SHELLFLAGS = --rcfile ../.devcontainer/.env -lc

# Forward goals to sub-make.
%:
	@riscv_make -f makefile.sw $@ CLI_FLAGS=$(CLI_FLAGS)
