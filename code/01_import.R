##=============================================================================
## 00. preliminaries ==========================================================
## 01. data import ============================================================
## 02. save output ============================================================
##=============================================================================

## 00. preliminaries ==========================================================

library(readr)
library(dplyr)

## 01. data import  ===========================================================

# import population counts from 2017 world population prospects
pop.df <- read_csv(here::here("data/01_raw/WPP2017_PBSAS.csv"))

# select only cases and variables needed
pop.df %>% 
  select(-AgeGrpStart, -AgeGrpSpan) %>% 
  mutate(AgeGrp = as.numeric(ifelse(AgeGrp == "80+", "80", AgeGrp)))-> pop

# import life table data
life_tables <- read_csv(here::here("data/01_raw/WPP2017_LT.csv"))


## 02. save output ============================================================

# save population data for mena countires
saveRDS(pop, here::here("data/02_interim/pop.rds"))

# save life expectancy data for mena countires
saveRDS(life_tables, here::here("data/02_interim/life_tables.rds"))