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
  group_by(Location, MidPeriod, Sex) %>% 
  summarise(RLE_15=FunSpline(ex,AgeGrpStart, 15))  %>% 
  spread(key = Sex, value = RLE_15)  -> old.age.threshold.5y

## 02.2. interpolate old age thresholds for single years ======================

# first expand to get all years needed
interpolating.years <- expand.grid(MidPeriod = seq(1950, 2100, by = 1),
                                   Location = unique(old.age.threshold.5y$Location))


# interpolate the threshold for each single year, within each Location,
# for all three Sex groups
old.age.threshold.5y %>% 
  right_join(interpolating.years) %>% 
  group_by(Location) %>% 
  mutate(Female= FunSpline(MidPeriod, Female, MidPeriod),
         Male = FunSpline(MidPeriod, Male, MidPeriod),
         Total = FunSpline(MidPeriod, Total, MidPeriod)) %>% 
  rename(Time = MidPeriod) ->   old.age.threshold.1y

rm(interpolating.years, old.age.threshold.5y)

## 02.3. interpolate population sizes at threslold age ======================

#  merge thresholds back with the full population table, 
# sliding them in as extra rows 
pop %>% 
  group_by(Location, Time) %>% 
  mutate(CumPop = cumsum(Total)) %>% 
  select(-Total, -Male, -Female) %>% 
  bind_rows(old.age.threshold.1y %>% 
              select(-Male, -Female) %>% 
              rename(Age = Total) %>% 
              mutate(threshold = Age)) %>% 
  arrange(Location, Time, threshold) %>% 
  fill(threshold) %>% 
  arrange(Location, Time, Age) %>% 
  mutate(CumPop = FunSpline(Age, CumPop, Age)) ->  total.pop.thresholds

# repeat for men only
pop %>% 
  group_by(Location, Time) %>% 
  mutate(CumPop = cumsum(Male)) %>% 
  select(-Total, -Male, -Female) %>% 
  bind_rows(old.age.threshold.1y %>% 
              select(-Total, -Female) %>% 
              rename(Age = Male) %>% 
              mutate(threshold = Age)) %>% 
  arrange(Location, Time, threshold) %>% 
  fill(threshold) %>% 
  arrange(Location, Time, Age) %>% 
  mutate(CumPop = FunSpline(Age, CumPop, Age)) ->  male.pop.thresholds

# and for women only
pop %>% 
  group_by(Location, Time) %>% 
  mutate(CumPop = cumsum(Female)) %>% 
  select(-Total, -Male, -Female) %>% 
  bind_rows(old.age.threshold.1y %>% 
              select(-Total, -Male) %>% 
              rename(Age = Female) %>% 
              mutate(threshold = Age)) %>% 
  arrange(Location, Time, threshold) %>% 
  fill(threshold) %>% 
  arrange(Location, Time, Age) %>% 
  mutate(CumPop = FunSpline(Age, CumPop, Age)) ->  female.pop.thresholds

## 02.4. find proportion over  threslold age (and over 65) ====================
total.pop.thresholds %>% 
  mutate(over.65 = ifelse(Age < 65, "under", "over"),
         over.threshold = ifelse(Age < threshold, "under", "over")) %>% 
  group_by(Location, Time, over.65) %>% 
  mutate(Pop.65 = max(CumPop)) %>% 
  group_by(Location, Time, over.threshold) %>% 
  mutate(Pop.threshold = max(CumPop)) %>% 
  group_by(Location, Time) %>% 
  summarise(under.t = first(Pop.threshold),
            total = last(Pop.threshold),
            under.65 = first(Pop.65)) %>% 
  mutate(prop.over.65 = (total-under.65)/total,
         prop.over.t = (total - under.t)/total) -> total.prop.over

# for men only
male.pop.thresholds %>% 
  mutate(over.65 = ifelse(Age < 65, "under", "over"),
         over.threshold = ifelse(Age < threshold, "under", "over")) %>% 
  group_by(Location, Time, over.65) %>% 
  mutate(Pop.65 = max(CumPop)) %>% 
  group_by(Location, Time, over.threshold) %>% 
  mutate(Pop.threshold = max(CumPop)) %>% 
  group_by(Location, Time) %>% 
  summarise(under.t = first(Pop.threshold),
            total = last(Pop.threshold),
            under.65 = first(Pop.65)) %>% 
  mutate(prop.over.65 = (total-under.65)/total,
         prop.over.t = (total - under.t)/total) -> male.prop.over

# for women only
female.pop.thresholds %>% 
  mutate(over.65 = ifelse(Age < 65, "under", "over"),
         over.threshold = ifelse(Age < threshold, "under", "over")) %>% 
  group_by(Location, Time, over.65) %>% 
  mutate(Pop.65 = max(CumPop)) %>% 
  group_by(Location, Time, over.threshold) %>% 
  mutate(Pop.threshold = max(CumPop)) %>% 
  group_by(Location, Time) %>% 
  summarise(under.t = first(Pop.threshold),
            total = last(Pop.threshold),
            under.65 = first(Pop.65)) %>% 
  mutate(prop.over.65 = (total-under.65)/total,
         prop.over.t = (total - under.t)/total) -> female.prop.over

# merge all three tables back together

total.prop.over %>% 
  select(-under.t, -total, -under.65) %>% 
  left_join(male.prop.over %>% 
              select(-under.t, -total, -under.65),
            by = c("Location", "Time"), 
            suffix = c(".total",".male")) %>% 
  left_join(female.prop.over %>% 
              select(-under.t, -total, -under.65)) %>% 
  rename(prop.over.t.female = prop.over.t,
         prop.over.65.female = prop.over.t) -> prop.over

  
## 03. data transformation ====================================================
# turn into percent instead of proportions
pop %>% 
  group_by(Location, Time) %>% 
  mutate(Male = 100*Male/sum(Total),
         Female = 100*Female/sum(Total)) -> pop

## 04. save demo data for methods  ============================================

life_tables %>% 
  filter(Location == "Algeria", Sex == "Total") -> demo
saveRDS(demo, here::here("data/03_processed/demo.rds"))

pop %>% 
  filter(Location == "Algeria", Time == 1988) %>% 
  select(Age, Total) -> demo.pop
saveRDS(demo.pop, here::here("data/03_processed/demo.pop.rds"))

## 05. save data for plotting  ================================================
saveRDS(pop, here::here("data/03_processed/pop.rds"))
saveRDS(prop.over, here::here("data/03_processed/prop.over.rds"))
saveRDS(old.age.threshold.1y, here::here("data/03_processed/threshold.1y.rds"))

## 05. save csv data for easy access ===========================================
prospective_ages <- left_join(old.age.threshold.1y, prop.over) %>% 
  select(-AgeGrp)
write_csv(prospective_ages, "results/04_human-readable/final.data.csv")
