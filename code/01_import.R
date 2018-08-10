##=============================================================================
## 00. preliminaries ==========================================================
## 01. data import ============================================================
## 02. save output ============================================================
##=============================================================================

## 00. preliminaries ==========================================================
library(readr)
library(dplyr)

## 01. data import  ===========================================================

# manual data frame of countries used in the analysis
cntryz <- data.frame(country = c("Algeria", "Bahrain", "Egypt", 
                                 "Iran (Islamic Republic of)", 
                                 "Iraq", "Israel", "Jordan", "Kuwait", 
                                 "Lebanon", "Libya", "Morocco", 
                                 "Oman", "State of Palestine", "Qatar", 
                                 "Saudi Arabia", "Syrian Arab Republic", 
                                 "Tunisia", "Turkey", "United Arab Emirates", 
                                 "Yemen"))
# import population counts
pop.df <- read_csv(here::here("data/raw/WPP2017_PBSAS.csv"))
#, col_types = "iciciniiinnn")

# select only cases and variables needed
pop.df %>% 
  filter(Location %in% pull(cntryz)) %>% 
  select(-AgeGrpStart, -AgeGrpSpan) %>% 
  mutate(AgeGrp = as.numeric(ifelse(AgeGrp == "80+", "80", AgeGrp)))-> mena.pop

# import life table data
lt.df <- read_csv(here::here("data/raw/WPP2017_LifeTable.csv"))

# select only cases and variables needed
lt.df %>% 
  filter(Location %in% pull(cntryz))-> mena.lt



## 02. save output ============================================================

# save population data for mena countires
saveRDS(mena.pop, here::here("data/interim/mena.pop.rds"))

# save life expectancy data for mena countires
saveRDS(mena.lt, here::here("data/interim/mena.lt.rds"))

