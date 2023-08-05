PHONY: update

LIB = neorv32
BRANCH = main

# Update submodule to newest branch and commit
update:
	@cd $(LIB)
	git checkout $(BRANCH)
	git pull
	@cd ..
	git add $(LIB)
	git commit
