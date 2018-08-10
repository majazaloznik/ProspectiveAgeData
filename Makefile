# VARIABLE DEFINITIONS  #######################################################
###############################################################################
# folders #####################################################################
DIR:= .#
CODE:= $(DIR)/code

DATA:= $(DIR)/data

FIG:= $(DIR)/figures

DT/P:= $(DATA)/processed
DT/R:= $(DATA)/raw
DT/I:= $(DATA)/interim

DOC:= $(DIR)/docs
JRN:= $(DOC)/journals
RPRT:= $(DOC)/reports

# FILES #######################################################################
# plot  files
FIG/plots := $(FIG)/pyramid*.eps $(FIG)/prop*.eps $(FIG)/thresh*.eps

# maps files
FIG/maps := $(FIG)/map*.eps

# all interim data filee
DT/I/.rds :=  $(DT/I)/*.rds

# all processed files
DT/P/.rds := $(DT/P)/*.rds

# poster filename
POSTER := $(DIR)/docs/presentations/PH14.02.Factsheet

# final human readable data 
RESULTS := $(DIR)/results/human-readable/final.data.csv

# COMMANDS ####################################################################
# recipe to make .dot file  of this makefile
define make2dot
	@echo creating the .dot file from the dependencies in this makefile ----------
	python $(DIR)/code/makefile2dot.py < $< > $@
	sed -i 's/rankdir="BT"/rankdir="TB"/' $(DT/P)/make.dot	
	@echo done -------------------------------------------------------------------
endef 

# recipe to make .png file  from the dot file
define dot2png
	@echo Creating the .png from the .dot ----------------------------------------
  Rscript -e "source('$<')"
	@echo done -------------------------------------------------------------------
endef

# recipe to knit pdf from first prerequisite
define rmd2pdf
	@echo creating the $(@F) file by knitting it in R. ---------------------------
  Rscript -e "suppressWarnings(suppressMessages(require(rmarkdown)));\
	render('$<', output_dir = '$(@D)', output_format = 'pdf_document',\
	quiet = TRUE )"
	-rm $(wildcard $(@D)/tex2pdf*) -fr
endef 

# recipe to knit html from first prerequisite
define rmd2html
	@echo creating the $(@F) file by knitting it in R.---------------------------
  Rscript -e "suppressWarnings(suppressMessages(require(rmarkdown))); \
	render('$<', output_dir = '$(@D)', output_format = 'html_document',\
	quiet = TRUE )"
endef 

# recipe run latex with bibtex
define tex2dvi
	latex -interaction=nonstopmode --output-directory=$(@D) --aux-directory=$(@D) $< 
  bibtex $(basename $@)
	latex -interaction=nonstopmode --output-directory=$(@D) --aux-directory=$(@D) $<
  latex -interaction=nonstopmode --output-directory=$(@D) --aux-directory=$(@D) $<
endef 

# recipe run dvips for a0poster i.e. move the header file
define dvi2ps
	cp docs/presentations/a0header.ps a0header.ps
	dvips  -Pdownload35 -q -o $@ $<
  rm a0header.ps
endef

# recipe for creating pdf from ps file
define ps2pdf
	ps2pdf $< $@
endef

# recipe for sourcing the prerequisite R file
define sourceR
	Rscript -e "source('$<')"
endef

# DEPENDENCIES   ##############################################################
###############################################################################

all: journal readme methods dot pdf

pdf: $(POSTER).pdf

.PHONY: all


# make chart from .dot #########################################################
dot: $(FIG)/make.png 

# make chart from .dot
$(FIG)/make.png: $(CODE)/dot2png.R $(DT/P)/make.dot
	@$(dot2png)

# make file .dot from the .makefile
$(DT/P)/make.dot: $(DIR)/Makefile
	@$(make2dot)


# journals from Rmds ###########################################################
journal: $(JRN)/journal.html $(JRN)/journal.pdf 

# journal (with graph) render to  pdf
$(JRN)/journal.pdf:  $(JRN)/journal.Rmd 
	$(rmd2pdf)

# journal (with graph) render to  html
$(JRN)/journal.html:  $(JRN)/journal.Rmd 
	$(rmd2html)


# README from Rmds #############################################################
readme: README.html

README.html: README.md $(FIG)/extract.png
	$(rmd2html)

# methods from Rmds ############################################################
methods: $(RPRT)/methods.pdf

$(RPRT)/methods.pdf:  $(RPRT)/methods.Rmd  $(DT/P)/demo.rds $(DT/P)/demo.pop.rds $(DOC)/bib.bib
	$(rmd2pdf)


# POSTER #######################################################################
$(POSTER).pdf: $(POSTER).ps
	$(ps2pdf)

$(POSTER).ps: $(POSTER).dvi
	$(dvi2ps)

$(POSTER).dvi: $(POSTER).tex $(DOC)/bib.bib $(FIG/maps) $(FIG/plots) $(FIG)/dglogo.eps
	$(tex2dvi)


# DATA ANALYSIS ################################################################
# MAPPING  #####################################################################
$(FIG/maps):  $(CODE)/04-mapping.R
	$(sourceR)
	
# required data and functions for 04-mapping - dependencies only
$(CODE)/04-mapping.R: $(DT/P)/prop.over.rds $(DT/P)/threshold.1y.rds $(DT/R)/ISO.country.codes.csv
	touch $@

# PLOTTING #####################################################################
$(FIG/plots): $(CODE)/03-plotting.R
	$(sourceR)
	
# required data and functions for 03-plotting - dependencies only
$(CODE)/03-plotting.R: $(DT/P)/prop.over.rds $(DT/P)/threshold.1y.rds $(DT/P)/mena.pop.rds $(CODE)/FunPlots.R
	touch $@

# calculate splines and process data   ########################################	
$(DT/P)/mena.pop.rds:  $(CODE)/02-transform-data.R
	Rscript -e "source('$<')"

# dependencies only
$(DT/P)/demo.rds $(DT/P)/demo.pop.rds $(DT/P)/prop.over.rds $(DT/P)/threshold.1y.rds $(RESULTS):  $(CODE)/02-transform-data.R

# required data for input to 02-clean-data
$(CODE)/02-transform-data.R: $(DT/I)/mena.pop.rds $(DT/I)/mena.lt.rds $(CODE)/FunSpline.R
	touch $@

# import and clean data #######################################################
	
$(DT/I)/mena.pop.rds: $(CODE)/01-import.R
	Rscript -e "source('$<')"

# dependency only
$(DT/I)/mena.lt.rds: $(CODE)/01-import.R

# required data for input to 01-import
$(CODE)/01-import.R: $(DT/R)/WPP2017_PBSAS.csv $(DT/R)/WPP2017_LT.csv
	touch $@

# download ISO country list data for mapping
$(DT/R)/ISO.country.codes.csv:
	curl  -o $@ "https://raw.githubusercontent.com/datasets/country-codes/master/data/country-codes.csv"

# download all WPP 2017 population data
$(DT/R)/WPP2017_PBSAS.csv: 
	curl -o $@ "https://esa.un.org/unpd/wpp/DVD/Files/1_Indicators%20(Standard)/CSV_FILES/WPP2017_PopulationBySingleAgeSex.csv"

# download all WPP 2017 life table data
$(DT/R)/WPP2017_LT.csv:
	curl  -o $@	"https://esa.un.org/unpd/wpp/DVD/Files/1_Indicators%20(Standard)/CSV_FILES/WPP2017_LifeTable.csv" 

   
       
    






