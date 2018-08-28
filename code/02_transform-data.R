##=============================================================================
## 00. preliminaries ==========================================================
## 01. data import ============================================================
## 02. data interpolation =====================================================
## 03. data transformation ====================================================
##=============================================================================

## 00. preliminaries ==========================================================
library(readr)
library(dplyr)
library(tidyr)
source(here::here("code/FunSpline.R"))

## 01. data import  =========================================================
# import population data 
pop <- readRDS(here::here("data/02_interim/pop.rds"))

# import life expectacy data 
life_tables <- readRDS(here::here("data/02_interim/life_tables.rds"))


## 02. data interpolation =====================================================
## 02.1 calculate old-age thresholds  based on abridged life table ============

# use splines to get old age threshold (15 years remaining life expectancy)
# for each year/country combination
# NB: x and y are swapped here on the assumption that there is only 
# one age where ex is 15. 
life_tables %>% 
  group_by(location, MidPeriod, Sex) %>% 
  summarise(RLE_15=FunSpline(ex,AgeGrpStart, 15))  %>% 
  spread(key = Sex, value = RLE_15) %>% 
  rename(male = Male, female = Female, total = Total) -> old.age.threshold.5y

## 02.2. interpolate old age thresholds for single years ======================
# first expand to get all years needed
interpolating.years <- expand.grid(MidPeriod = seq(1950, 2100, by = 1),
                                   location = unique(old.age.threshold.5y$location))

# interpolate the threshold for each single year, within each location,
# for all three Sex groups
old.age.threshold.5y %>% 
  right_join(interpolating.years) %>% 
  group_by(location) %>% 
  mutate(female= FunSpline(MidPeriod, female, MidPeriod),
         male = FunSpline(MidPeriod, male, MidPeriod),
         total = FunSpline(MidPeriod, total, MidPeriod)) %>% 
  rename(time = MidPeriod) ->   thresholds_1y

rm(interpolating.years, old.age.threshold.5y)

## 02.3. interpolate population sizes at threslold age ======================
#  merge thresholds back with the full population table, 
# sliding them in as extra rows 
pop %>% 
  mutate(age_group_end = age + 1) %>% 
  group_by(location, time) %>% 
  mutate(cum_pop_total = cumsum(total),
         cum_pop_female = cumsum(female),
         cum_pop_male = cumsum(male))  %>% 
  select(-total, -male, -female) %>% 
  bind_rows(thresholds_1y %>%  
              select(-female, -male) %>% 
              rename(age_group_end = total) %>% 
              mutate(threshold_total = age_group_end)) %>% 
  bind_rows(thresholds_1y %>% 
              select(-total, -male) %>% 
              rename(age_group_end = female) %>% 
              mutate(threshold_female = age_group_end)) %>% 
  bind_rows(thresholds_1y %>%  
              select(-female, -total) %>% 
              rename(age_group_end = male) %>% 
              mutate(threshold_male = age_group_end)) %>% 
  arrange(location, time, threshold_total) %>%  
  fill(threshold_total)  %>% 
  arrange(location, time, threshold_female) %>%  
  fill(threshold_female) %>% 
  arrange(location, time, threshold_male) %>%  
  fill(threshold_male) %>% 
  arrange(location, time, age_group_end) %>% 
  mutate(cum_pop_total = FunSpline(age_group_end, cum_pop_total, age_group_end),
         cum_pop_female = FunSpline(age_group_end, cum_pop_female, age_group_end),
         cum_pop_male = FunSpline(age_group_end, cum_pop_male, age_group_end)) -> pop_thresholds

## 02.4. find proportion over  threslold age (and over 65) ====================

pop_thresholds %>% 
  mutate(over_65 = ifelse(age_group_end <= 65 , "under", "over"),
         over_threshold_total = ifelse(age_group_end <= threshold_total, "under", "over"),
         over_threshold_female = ifelse(age_group_end <= threshold_female, "under", "over"),
         over_threshold_male = ifelse(age_group_end <= threshold_male, "under", "over")) %>% 
  group_by(location, time, over_65) %>% 
  mutate(pop_65_total = max(cum_pop_total),
         pop_65_female = max(cum_pop_female),
         pop_65_male = max(cum_pop_male)) %>% 
  group_by(location, time, over_threshold_total) %>% 
  mutate(pop_threshold_total = max(cum_pop_total)) %>% 
  group_by(location, time, over_threshold_female) %>% 
  mutate(pop_threshold_female = max(cum_pop_female)) %>% 
  group_by(location, time, over_threshold_male) %>% 
  mutate(pop_threshold_male = max(cum_pop_male))  %>% 
  group_by(location, time) %>% 
  summarise(pop_under_65_total = first(pop_65_total),
            pop_under_65_female = first(pop_65_female),
            pop_under_65_male = first(pop_65_male),
            pop_under_threshold_total = first(pop_threshold_total),
            pop_under_threshold_female = first(pop_threshold_female),
            pop_under_threshold_male = first(pop_threshold_male),
            pop_all_total = last(pop_65_total),
            pop_all_female = last(pop_65_female),
            pop_all_male = last(pop_65_male)) %>% 
  mutate(prop_over_65_total = 1-pop_under_65_total/pop_all_total,
         prop_over_65_female = 1-pop_under_65_female/pop_all_female,
         prop_over_65_male = 1-pop_under_65_male/pop_all_male,
         prop_over_threshold_total = 1-pop_under_threshold_total/pop_all_total,
         prop_over_threshold_female = 1-pop_under_threshold_female/pop_all_female,
         prop_over_threshold_male = 1-pop_under_threshold_male/pop_all_male) %>% 
  select(location, time, starts_with("prop")) -> prop_over 

## 03. save demo data extract for methods.Rmd  ================================

life_tables %>% 
  filter(location == "Algeria", Sex == "Total") -> demo
saveRDS(demo, here::here("data/03_processed/demo.rds"))

pop %>% 
  filter(location == "Algeria", time == 1988) %>% 
  select(age, total) -> demo.pop
saveRDS(demo.pop, here::here("data/03_processed/demo.pop.rds"))

## 04. save csv data for easy access ===========================================
prospective_ages <- left_join(thresholds_1y, prop_over) 
write_csv(prospective_ages, "data/04_human-readable/2017_prospective-ages.csv")

