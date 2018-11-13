library(readr)
library(tidyr)

wb <- readr::read_csv(unz(description = "C:/Users/sfos0247/Downloads/API_SP.POP.65UP.TO.ZS_DS2_en_csv_v2_10083465.zip"
                    , filename = "API_SP.POP.65UP.TO.ZS_DS2_en_csv_v2_10083465.csv"), col_names = TRUE,
                skip = 4)

my_data <- read_csv("data/04_human-readable/2017_prospective-ages.csv")

wb %>% 
  select(-X63, -`Indicator Name`, -`Indicator Code`) %>% 
   gather(key = time, value = prop_over_65_total_wb,3:60) %>% 
  mutate(time = as.numeric(time),
         prop_over_65_total_wb = prop_over_65_total_wb/100) %>% 
  rename(location = `Country Name`) %>% 
  left_join(my_data %>% 
              select(location, time,prop_over_65_total)) %>% 
  na.omit() %>% 
  mutate(test = !all.equal( prop_over_65_total, prop_over_65_total_wb, tolerance = 10e-6)) %>% 
  summarise(wrong = sum(test)) 

# all are correct to 7 significant digits.