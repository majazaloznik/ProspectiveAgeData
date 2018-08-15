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
  rename(time = MidPeriod) ->   old.age.threshold.1y

rm(interpolating.years, old.age.threshold.5y)

## 02.3. interpolate population sizes at threslold age ======================
#  merge thresholds back with the full population table, 
# sliding them in as extra rows 
pop %>% 
  group_by(location, time) %>% 
  mutate(CumPop = cumsum(total)) %>% 
  select(-total, -male, -female) %>% 
  bind_rows(old.age.threshold.1y %>% 
              select(-male, -female) %>% 
              rename(age = total) %>% 
              mutate(threshold = age)) %>% 
  arrange(location, time, threshold) %>% 
  fill(threshold) %>% 
  arrange(location, time, age) %>% 
  mutate(CumPop = FunSpline(age, CumPop, age)) ->  total.pop.thresholds

# repeat for men only
pop %>% 
  group_by(location, time) %>% 
  mutate(CumPop = cumsum(male)) %>% 
  select(-total, -male, -female) %>% 
  bind_rows(old.age.threshold.1y %>% 
              select(-total, -female) %>% 
              rename(age = male) %>% 
              mutate(threshold = age)) %>% 
  arrange(location, time, threshold) %>% 
  fill(threshold) %>% 
  arrange(location, time, age) %>% 
  mutate(CumPop = FunSpline(age, CumPop, age)) ->  male.pop.thresholds

# and for women only
pop %>% 
  group_by(location, time) %>% 
  mutate(CumPop = cumsum(female)) %>% 
  select(-total, -male, -female) %>% 
  bind_rows(old.age.threshold.1y %>% 
              select(-total, -male) %>% 
              rename(age = female) %>% 
              mutate(threshold = age)) %>% 
  arrange(location, time, threshold) %>% 
  fill(threshold) %>% 
  arrange(location, time, age) %>% 
  mutate(CumPop = FunSpline(age, CumPop, age)) ->  female.pop.thresholds

## 02.4. find proportion over  threslold age (and over 65) ====================
total.pop.thresholds %>% 
  mutate(over.65 = ifelse(age < 65, "under", "over"),
         over.threshold = ifelse(age <= threshold, "under", "over")) %>% 
  group_by(location, time, over.65) %>% 
  mutate(Pop.65 = max(CumPop)) %>% 
  group_by(location, time, over.threshold) %>% 
  mutate(Pop.threshold = max(CumPop)) %>% 
  group_by(location, time) %>% 
  summarise(under.t = first(Pop.threshold),
            total = last(Pop.threshold),
            under.65 = first(Pop.65)) %>% 
  mutate(prop.over.65 = (total-under.65)/total,
         prop.over.t = (total - under.t)/total) -> total.prop.over

# for men only
male.pop.thresholds %>% 
  mutate(over.65 = ifelse(age < 65, "under", "over"),
         over.threshold = ifelse(age <= threshold, "under", "over")) %>% 
  group_by(location, time, over.65) %>% 
  mutate(Pop.65 = max(CumPop)) %>% 
  group_by(location, time, over.threshold) %>% 
  mutate(Pop.threshold = max(CumPop)) %>% 
  group_by(location, time) %>% 
  summarise(under.t = first(Pop.threshold),
            total = last(Pop.threshold),
            under.65 = first(Pop.65)) %>% 
  mutate(prop.over.65 = (total-under.65)/total,
         prop.over.t = (total - under.t)/total) -> male.prop.over

# for women only
female.pop.thresholds %>% 
  mutate(over.65 = ifelse(age < 65, "under", "over"),
         over.threshold = ifelse(age <= threshold, "under", "over")) %>% 
  group_by(location, time, over.65) %>% 
  mutate(Pop.65 = max(CumPop)) %>% 
  group_by(location, time, over.threshold) %>% 
  mutate(Pop.threshold = max(CumPop)) %>% 
  group_by(location, time) %>% 
  summarise(under.t = first(Pop.threshold),
            total = last(Pop.threshold),
            under.65 = first(Pop.65)) %>% 
  mutate(prop.over.65 = (total-under.65)/total,
         prop.over.t = (total - under.t)/total) -> female.prop.over

## 02.5. merge all three tables back together==================================
total.prop.over %>% 
  select(-under.t, -total, -under.65) %>% 
  left_join(male.prop.over %>% 
              select(-under.t, -total, -under.65),
            by = c("location", "time"), 
            suffix = c(".total",".male")) %>% 
  left_join(female.prop.over %>% 
              select(-under.t, -total, -under.65)) %>% 
  rename(prop.over.t.female = prop.over.t,
         prop.over.65.female = prop.over.t) -> prop.over


## 03. save demo data extract for methods.Rmd  ================================

life_tables %>% 
  filter(location == "Algeria", Sex == "Total") -> demo
saveRDS(demo, here::here("data/03_processed/demo.rds"))

pop %>% 
  filter(location == "Algeria", time == 1988) %>% 
  select(age, total) -> demo.pop
saveRDS(demo.pop, here::here("data/03_processed/demo.pop.rds"))

## 04. save csv data for easy access ===========================================
prospective_ages <- left_join(old.age.threshold.1y, prop.over) 
write_csv(prospective_ages, "data/04_human-readable/2017_prospective-ages.csv")

