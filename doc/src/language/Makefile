.PHONY: clean example-code pictures

TEXFILES=inline-bom.tex mlb.tex
PDFS=$(TEXFILES:.tex=.pdf)

all: $(PDFS)
	

%.pdf : %.tex example-code pictures
	bibtex $* || echo ""
	pdflatex $<
	pdflatex $<

example-code:	
	make -C example-code

pictures:
	make -C pictures

spellcheck:
	ispell -t $(TEXFILES)

clean:
	rm -f *.{pdf,log,aux,ps,dvi,bbl,blg} *~
	make -C example-code clean
	make -C pictures clean
