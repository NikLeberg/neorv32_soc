# Define bash as the shell to use for sub-shells. The environment variable
# $BASH_ENV points to the .env file containing aliases of commands for running
# in docker containers. These aliases can then be used in recipies.
SHELL = BASH_ENV=../.devcontainer/.env /bin/bash

# Forward goals to sub-make.
%:
	@riscv_make -f makefile.sw $@ CLI_FLAGS=$(CLI_FLAGS)
