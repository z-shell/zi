# This Makefile is to convert supplied Asciidoc files into
# other formats like pdf and man. The files contain ZI's
# code documentation.
# *.adoc files are generated root directory Makefile.

all: man pdf

# MAN
# Converted with a2x from asciidoc package

man: man/zi.zsh.1 man/side.zsh.1 man/install.zsh.1 man/autoload.zsh.1

man/zi.zsh.1:
	@mkdir -p man
	a2x --verbose -L --doctype manpage --format manpage -D man zi.zsh.adoc

man/side.zsh.1:
	@mkdir -p man
	a2x --verbose -L --doctype manpage --format manpage -D man side.zsh.adoc

man/install.zsh.1:
	@mkdir -p man
	a2x --verbose -L --doctype manpage --format manpage -D man install.zsh.adoc

man/autoload.zsh.1:
	@mkdir -p man
	a2x --verbose -L --doctype manpage --format manpage -D man autoload.zsh.adoc

# PDF
# Uses asciidoctor not a2x (i.e. not asciidoc)

pdf: pdf/zi.zsh.pdf pdf/side.zsh.pdf pdf/install.zsh.pdf pdf/autoload.zsh.pdf

pdf/zi.zsh.pdf:
	@mkdir -p pdf
	asciidoctor -a reproducible -b pdf -r asciidoctor-pdf -D pdf zi.zsh.adoc

pdf/side.zsh.pdf:
	@mkdir -p pdf
	asciidoctor -a reproducible -b pdf -r asciidoctor-pdf -D pdf side.zsh.adoc

pdf/install.zsh.pdf:
	@mkdir -p pdf
	asciidoctor -a reproducible -b pdf -r asciidoctor-pdf -D pdf install.zsh.adoc

pdf/autoload.zsh.pdf:
	@mkdir -p pdf
	asciidoctor -a reproducible -b pdf -r asciidoctor-pdf -D pdf autoload.zsh.adoc

clean:
	rm -rf man pdf data

.PHONY: man pdf clean
