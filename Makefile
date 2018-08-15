# VARIABLE DEFINITIONS  #######################################################
###############################################################################
# folders #####################################################################
DIR:= .#
CODE:= $(DIR)/code
DOCS:= $(DIR)/docs
FIG:= $(DIR)/figures
DATA:= $(DIR)/data

DT01:= $(DATA)/01_raw
DT02:= $(DATA)/02_interim
DT03:= $(DATA)/03_processed
DT04:= $(DATA)/04_human-readable

# FILES #######################################################################
RESULTS = $(DT04)/human-readable.csv
DEMOS = $(DT03)/demo.rds $(DT03)/demo.pop.rds
INTERIM = $(DT02)/pop.rds $(DT02)/life_tables.rds
# COMMANDS ####################################################################
# recipe to make .dot file  of this makefile
define make2dot
	@echo creating the .dot file from the dependencies in this makefile ----------
	python $(DIR)/code/makefile2dot.py < $< > $@
	sed -i 's/rankdir="BT"/rankdir="TB"/' $(DT03)/make.dot	
	@echo done -------------------------------------------------------------------
endef 

# recipe to make .png file  from the dot file
define dot2png
	@echo Creating the .png from the .dot ----------------------------------------
  Rscript -e "source('$<')" $(DT03:./%=%) $(FIG:./%=%)
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

# recipe for sourcing the prerequisite R file
define sourceR
	@echo sourcing the prerequisite R file ---------------------------------------
	Rscript -e "source('$<')"
endef

# DEPENDENCIES   ##############################################################
###############################################################################

.PHONY: all

all: readme methods dot results codebook

results: $(RESULTS)

# make chart from .dot #########################################################
dot: $(FIG)/make.png 

# make chart from .dot
$(FIG)/make.png: $(CODE)/dot2png.R $(DT03)/make.dot
	@$(dot2png)

# make file .dot from the .makefile
$(DT03)/make.dot: $(DIR)/Makefile
	@$(make2dot)


# README from Rmds #############################################################
readme: README.html

README.html: README.md 
	$(rmd2html)

# methods from Rmds ############################################################
methods: $(DOCS)/methods.pdf

$(DOCS)/methods.pdf:  $(DOCS)/methods.Rmd  $(DEMOS) $(DOCS)/bib.bib
	$(rmd2pdf)

# codebook from Rmds ############################################################
codebook: $(DOCS)/codebook.pdf

$(DOCS)/codebook.pdf:  $(DOCS)/codebook.Rmd $(DOCS)/bib.bib
	$(rmd2pdf)

# calculate splines and process data   ########################################	
$(RESULTS) $(DEMOS):  $(CODE)/02_transform-data.R
	Rscript -e "source('$<')"

# required data for input to 02-clean-data
$(CODE)/02_transform-data.R: $(DT02)/pop.rds $(DT02)/life_tables.rds $(CODE)/FunSpline.R
	touch $@

# import and clean data #######################################################
	
$(DT02)/pop.rds $(DT02)/life_tables.rds: $(CODE)/01_import.R
	Rscript -e "source('$<')"

# required data for input to 01-import
$(CODE)/01_import.R: $(DT01)/WPP2017_PBSAS.csv $(DT01)/WPP2017_LT.csv
	touch $@
	
# import data #################################################################
# download all WPP 2017 population data
$(DT01)/WPP2017_PBSAS.csv: 
	curl -o $@ "https://esa.un.org/unpd/wpp/DVD/Files/1_Indicators%20(Standard)/CSV_FILES/WPP2017_PopulationBySingleAgeSex.csv"

# download all WPP 2017 life table data
$(DT01)/WPP2017_LT.csv:
	curl  -o $@	"https://esa.un.org/unpd/wpp/DVD/Files/1_Indicators%20(Standard)/CSV_FILES/WPP2017_LifeTable.csv" 

   
       
    






