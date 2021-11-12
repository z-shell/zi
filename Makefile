all: zinit.zsh.zwc zinit-side.zsh.zwc zinit-install.zsh.zwc zinit-autoload.zsh.zwc

%.zwc: %
	lib/zcompile $<

#alltest: test testB testC testD testE
#test:
#	make VERBOSE=$(VERBOSE) NODIFF=$(NODIFF) DEBUG=$(DEBUG) OPTDUMP=$(OPTDUMP) OPTS=$(OPTS) -C test test
#testB:
#	make VERBOSE=$(VERBOSE) NODIFF=$(NODIFF) DEBUG=$(DEBUG) OPTDUMP=$(OPTDUMP) OPTS="kshglob" -C test test
#testC:
#	make VERBOSE=$(VERBOSE) NODIFF=$(NODIFF) DEBUG=$(DEBUG) OPTDUMP=$(OPTDUMP) OPTS="noextendedglob" -C test test
#testD:
#	make VERBOSE=$(VERBOSE) NODIFF=$(NODIFF) DEBUG=$(DEBUG) OPTDUMP=$(OPTDUMP) OPTS="ksharrays" -C test test
#testE:
#	make VERBOSE=$(VERBOSE) NODIFF=$(NODIFF) DEBUG=$(DEBUG) OPTDUMP=$(OPTDUMP) OPTS="ignoreclosebraces" -C test test

docs: zinit.zsh zinit-side.zsh zinit-install.zsh zinit-autoload.zsh
	rm -rf docs/zsdoc/data docs/zsdoc/*.adoc
	cd docs && \
	zsd -v --scomm --cignore \
	'(\#*FUNCTION:*{{{*|\#[[:space:]]#}}}*)' \
	../zinit.zsh ../zinit-side.zsh ../zinit-install.zsh ../zinit-autoload.zsh
	cd ..

html: docs
	cd docs/zsdoc && \
	asciidoctor zinit.zsh.adoc && \
	asciidoctor zinit-side.zsh.adoc && \
	asciidoctor zinit-install.zsh.adoc && \
	asciidoctor zinit-autoload.zsh.adoc
	cd ..

clean:
	rm -f zinit.zsh.zwc zinit-side.zsh.zwc zinit-install.zsh.zwc zinit-autoload.zsh.zwc
	rm -rf docs/zsdoc/data

.PHONY: all clean docs
