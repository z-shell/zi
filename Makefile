all: zinit.zsh.zwc side.zsh.zwc install.zsh.zwc autoload.zsh.zwc

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

doc: zinit.zsh side.zsh install.zsh autoload.zsh
	rm -rf docs/zsdoc/data docs/zsdoc/*.adoc
	cd docs && \
	zsd -v --scomm --cignore \
	'(\#*FUNCTION:*{{{*|\#[[:space:]]#}}}*)' \
	../zinit.zsh ../lib/zsh/side.zsh ../lib/zsh/install.zsh ../lib/zsh/autoload.zsh
	cd ..

html: adoc
	cd docs/zsdoc && \
	asciidoctor zinit.zsh.adoc && \
	asciidoctor side.zsh.adoc && \
	asciidoctor install.zsh.adoc && \
	asciidoctor autoload.zsh.adoc
	cd ..

clean:
	rm -f zinit.zsh.zwc lib/zsh/side.zsh.zwc /lib/zsh/install.zsh.zwc /lib/zsh/autoload.zsh.zwc
	rm -rf docs/zsdoc/data

.PHONY: all clean doc
