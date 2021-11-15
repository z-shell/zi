all: ../lib/zi.zsh.zwc ../lib/zsh/side.zsh.zwc ../lib/zsh/install.zsh.zwc ../lib/zsh/autoload.zsh.zwc

%.zwc: %
	../lib/zcompile $<

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

doc: ../zi.zsh ../lib/zsh/side.zsh ../lib/zsh/install.zsh ../lib/zsh/autoload.zsh
	rm -rf zsdoc/data zsdoc/*.adoc
	zsd -v --scomm --cignore '(\#*FUNCTION:*{{{*|\#[[:space:]]#}}}*)' \
	../zi.zsh ../lib/zsh/side.zsh ../lib/zsh/install.zsh ../lib/zsh/autoload.zsh

html: doc
	cd zsdoc && \
	asciidoctor zi.zsh.adoc && \
	asciidoctor side.zsh.adoc && \
	asciidoctor install.zsh.adoc && \
	asciidoctor autoload.zsh.adoc

clean:
	rm -f ../zi.zsh.zwc ../lib/zsh/side.zsh.zwc ../lib/zsh/install.zsh.zwc ../lib/zsh/autoload.zsh.zwc
	rm -rf zsdoc/data

.PHONY: all clean doc html
