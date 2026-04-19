#### FUNBEL ####
#### Running libraries ####
setwd("/scratch/gent/vo/001/gvo00142/data_share_group/glen/data_RL_vsc46998_KVG")
library(tidyverse)
#library(rgdal)
library(leaflet)
library(rlang)
library(sf)
library(sp)
library(readxl)
library(lubridate)
library(openxlsx)
library(dplyr)
conflicted::conflicts_prefer(dplyr::filter)
library(lwgeom)
library(stringr)
library(ggplot2)
#library(effectclass)
library(ggsci)
#library(INBOtheme)
library(readr)
library(sjPlot)
library(tidyr)
library(stats)

#### Reading in Funbel data ####
Data_updated <- read_excel("Data_updated.xlsx", 
                           sheet = "Data genera")
str(Data_updated)
names(Data_updated)
head(Data_updated)
#### Creating new columns ####
# Kwartierhokken
Data_updated <- Data_updated %>% 
  mutate(Uurhok_new = str_c(Uurhok, Kwartier, sep ="-")) %>%
  mutate(Uurhok_new2 = str_replace_all(Uurhok_new, "\\.", "-") %>% tolower(),
         ifbluurhok = Uurhok_new2)
Data_updated <- Data_updated %>%
  select(-Uurhok_new, -Uurhok_new2, -Uurhok)
# Year
Data_updated <- Data_updated %>%
  mutate(
    Year = ifelse(
      !is.na(as.Date(Datum, format = "%Y-%m-%d", errors = "coerce")),
      as.integer(format(as.Date(Datum, format = "%Y-%m-%d"), "%Y")),
      as.integer(str_extract(Datum, "^\\d{4}"))
    )
  )
Data_updated$Year <- as.numeric(Data_updated$Year)
# Old names species 
Data_updated$Old_name <- paste(Data_updated$Genus, Data_updated$Soortnaam, sep = " ")

#### Final adjustments to the data ####
# Final taxonomic corrections
Data_updated$Species <- gsub("Pulveroboletus gentilis", "Aureoboletus gentilis", Data_updated$Species)
Data_updated$Species <- gsub("Russula olivaceoviolascens", "Russula atrorubens", Data_updated$Species)
Data_updated$Species <- gsub("Microglossum atropurpureum", "Geoglossum atropurpureum", Data_updated$Species)
Data_updated$Species <- gsub("Russula emeticella", "Russula silvestris", Data_updated$Species)
Data_updated$Species <- gsub("Xerocomellus armeniacus", "Rheubarbariboletus armeniacus", Data_updated$Species)

# Remove sp.observations from the dataset
Data_updated <- Data_updated[nchar(Data_updated$Species) > 1, ]
Data_updated <- Data_updated[!grepl('sp\\.', Data_updated$Species, ignore.case = TRUE), ]

# Remove the s.s. from any species names that still have it
Data_updated$Species <- gsub(' s\\.s\\.', '', Data_updated$Species, ignore.case = TRUE)

# Identify species with both normal and s.l. variants
species_both <- unique(sub(' s\\.l\\.$', '', Data_updated$Species[grep(' s\\.l\\.$', Data_updated$Species, ignore.case = TRUE)]))
species_both <- species_both[!species_both %in% "Lactarius aurantiacus"]
# Create a logical condition to keep rows with s.l. variant only if normal variant doesn't exist
condition <- !(Data_updated$Species %in% paste0(species_both, ' s.l.') & !Data_updated$Species %in% species_both)
# Filter the dataset based on the condition
Data_updated <- Data_updated[condition, ]

# Removing those observations without a proper observation date 
g <- Data_updated %>%
  filter(Year >= 1800 & Year <= 2023)
extra_observations <- Data_updated %>%
  anti_join(g, by = NULL)
write.xlsx(extra_observations, "/scratch/gent/vo/001/gvo00142/data_share_group/glen/data_RL_vsc46998_KVG/extra_observations.xlsx", rowNames = FALSE)
Data_updated <- Data_updated %>%
  anti_join(extra_observations)

#### Loading spacial files ####
load("Vlaanderen.Rdata")
load("Hoofdrivieren.Rdata")

# Read in the ifbl1km-quadrants of the Flemish provinces 
ecoVL <- read.csv2("tblIFBLkwartierhokEcodistrict.csv", 
                   sep = ";")
ecoVL <- ecoVL %>% 
  rename(Ecoregio = REGIO,
         Ecodistrict = DISTRICT,
         ifbluurhok = IFBLuurhok)
head(ecoVL)
unique(ecoVL$Ecoregio) 


# Read in the IFBL 1 km shapefile
xyIFBLuur <- st_read(
  dsn = "/scratch/gent/vo/001/gvo00142/data_share_group/glen/data_RL_vsc46998_KVG",
  layer = "ifbl01x01"
)

# Check CRS, only transform if needed
st_crs(xyIFBLuur)
if (is.na(st_crs(xyIFBLuur)) || st_crs(xyIFBLuur)$epsg != 31370) {
  xyIFBLuur <- st_transform(xyIFBLuur, 31370)
}

# Read in the eco-district shapefile
shapeEcoVLsf <- st_read(
  dsn = "/scratch/gent/vo/001/gvo00142/data_share_group/glen/data_RL_vsc46998_KVG",
  layer = "ecodistrict2002"
)

shapeEcoVLsf <- shapeEcoVLsf %>%
  dplyr::rename(Ecodistrict = DISTRICT)

print(shapeEcoVLsf)
head(shapeEcoVLsf)
unique(shapeEcoVLsf$Ecoregio)

# Read in the eco-region shapefile
shapeEcoregioVLsf <- st_read(
  dsn = "/scratch/gent/vo/001/gvo00142/data_share_group/glen/data_RL_vsc46998_KVG",
  layer = "ecoregio2002"
)

shapeEcoregioVLsf <- shapeEcoregioVLsf %>%
  dplyr::rename(Ecoregio = REGIO)

print(shapeEcoregioVLsf)
head(shapeEcoregioVLsf)
unique(shapeEcoregioVLsf$Ecoregio)

# Read in a file containing only the ifbl1km-quadrants belong to the Flemish Region
provVL <- read.csv2("/scratch/gent/vo/001/gvo00142/data_share_group/glen/data_RL_vsc46998_KVG/tblIFBLkwartier.csv",
                    sep = ";") %>% 
  rename(IFBLuur = IFBL)
head(provVL)
nrow(provVL)

xyIFBLuursf <- inner_join(provVL,
                          xyIFBLuursf,
                          by = c("ifbluurhok" = "Name"))

#### Visualising the data ####
n <- "Alldata_Funbel"

# Make a condensed table
condensAllRecordsPerJaar <- Data_updated%>% 
  filter(Year >= 1800) %>% 
  group_by(Year) %>% 
  summarise(count = n())
head(condensAllRecordsPerJaar) 
condensAllRecordsPerJaar_Funbel <- condensAllRecordsPerJaar

# Join both files containing only the Flemish ifbl1km-quadrants 
condensAllVL <- inner_join(Data_updated,
                           provVL,
                           by = "ifbluurhok")
head(condensAllVL)
nrow(condensAllVL)
condensAllVL <- read_excel("condensAllVL.xlsx")
head(condensAllVL)
str(condensAllVL)
#### Condensed observations à Year [Plot 1] ####
p <- ggplot(condensAllRecordsPerJaar,
            aes(x = Year,
                y = count)) +
  geom_col() +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45,
                                   hjust = 1)) +
  ggtitle("Funbel") + xlab("Year") + ylab("Number of condensed observations à year") +
  theme(plot.title = element_text(hjust = 0.5))
p
ggsave(paste(n, "_gegevens_per_jaar.png"), plot = p, device = "png", path = "/scratch/gent/vo/001/gvo00142/data_share_group/glen/data_RL_vsc46998_KVG/Alldata_Funbel")

#### Condensed observations à Year (>= 1980) [Plot2] ####
condensAllRecordsPerJaar2 <- condensAllRecordsPerJaar %>% 
  filter(Year >= 1980)

p <- ggplot(condensAllRecordsPerJaar2,
            aes(x = Year,
                y = count)) +
  geom_col() +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45,
                                   hjust = 1)) +
  geom_hline(yintercept = 100,
             colour = "darkgreen",
             size = 1)
p
ggsave(paste(n, "gegevens_per_jaar_vanaf1980.png"), plot = p, device = "png", path = "/scratch/gent/vo/001/gvo00142/data_share_group/glen/data_RL_vsc46998_KVG/Alldata_Funbel")

#### Ifbl1km-quadrants surveyed in periode 1 (1800-2000) [Plot3] ####
# Establish period 1
beginjaarP1 <- 1800
eindjaarP1 <- 2000

# Filter data from period 1
P1 <- condensAllVL %>% 
  filter(Year >= beginjaarP1 & Year <= eindjaarP1) %>% 
  dplyr::select(Species,
                ifbluurhok) %>% 
  group_by(Species,
           ifbluurhok) %>% 
  summarise()
head(P1)
nrow(P1)
unique_ifbl <- unique(P1$ifbluurhok)
P1_count <- as.numeric(length(unique_ifbl))

# Condens and count the number of species observed à ifbl1km-quadrant
nSpecsIFBLP1 <- P1 %>% 
  group_by(ifbluurhok) %>% 
  summarise(nSpecsP1 = n())
head(nSpecsIFBLP1)
str(xyIFBLuursf)
# Plotting the number of species observed à ifbl1km-quadrant in period 1
xyP1 <- left_join(nSpecsIFBLP1,
                   xyIFBLuursf,
                   by = "ifbluurhok")
head(xyP1)

p <- ggplot(xyP1) +
  geom_sf(aes(geometry = geometry),
          size = 5) +
  scale_colour_gradient(low = "yellow",
                        high  = "darkgreen") +
  geom_polygon(data = Vlaanderen,
               aes(x = long,
                   y = lat,
                   group = group),
               fill = "transparent") +
  geom_path(data = Vlaanderen,
            aes(x = long,
                y = lat,
                group = group),
            colour = "black") +
  geom_polygon(data = Hoofdrivieren,
               aes(x = long,
                   y = lat,
                   group = group),
               fill = "transparent") +
  geom_path(data = Hoofdrivieren,
            aes(x = long,
                y  =lat,
                group = group),
            colour = "blue") +
  coord_sf() +
  theme_bw() 
p
ggsave(paste(n, "_periode1.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/Alldata_Funbel")

#### Ifbl1km-quadrants surveyed in periode 2 (2001-2023) [Plot4] ####
# Establish period 2
beginjaarP2 <- 2001
eindjaarP2 <- 2023

# Filter data from period 2
P2 <- condensAllVL %>% 
  filter(Year >= beginjaarP2 & Year <= eindjaarP2) %>% 
  dplyr::select(Species,
                ifbluurhok) %>% 
  group_by(Species,
           ifbluurhok) %>% 
  summarise()
head(P2)
nrow(P2)
unique_ifbl <- unique(P2$ifbluurhok)
P2_count <- as.numeric(length(unique_ifbl))

# Condens and count the number of species observed à ifbl1km-quadrant in period 2
nSpecsIFBLP2 <- P2 %>% 
  group_by(ifbluurhok) %>% 
  summarise(nSpecsP2 = n())
head(nSpecsIFBLP2)

# Plotting the number of species observed à ifbl1km-quadrant in period 2
xyP2 <- inner_join(nSpecsIFBLP2,
                   xyIFBLuursf,
                   by = "ifbluurhok")
head(xyP2)

p <- ggplot(xyP2) +
  geom_sf(aes(geometry = geometry),
          size = 5) +
  scale_colour_gradient(low = "yellow",
                        high  = "darkgreen") +
  geom_polygon(data = Vlaanderen,
               aes(x = long,
                   y = lat,
                   group = group),
               fill = "transparent") +
  geom_path(data=Vlaanderen,
            aes(x = long,
                y = lat,
                group = group),
            colour = "black") +
  geom_polygon(data = Hoofdrivieren,
               aes(x = long,
                   y = lat,
                   group = group),
               fill = "transparent") +
  geom_path(data = Hoofdrivieren,
            aes(x = long,
                y = lat,
                group = group),
            colour = "blue") +
  coord_sf() +
  theme_bw() 
p
ggsave(paste(n, "_periode2.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/Alldata_Funbel")

#### Combined plot of observations done in period 1 & 2 (1800-2023) [Plot5] ####
xyP1$Period <- "Period 1"
xyP2$Period <- "Period 2"
colnames(xyP1)[2] <- "nSpecs"
colnames(xyP2)[2] <- "nSpecs"
data_P1P2 <- rbind(xyP1, xyP2)
unique_quadrants <- unique(data_P1P2$ifbluurhok)
length(unique_quadrants)

# Identify quadrants present in both periods
both_periods_quadrants <- intersect(data_P1P2$ifbluurhok[data_P1P2$Period == "Period 1"],
                                    data_P1P2$ifbluurhok[data_P1P2$Period == "Period 2"])

# Assign "Both" to the Period column for quadrants present in both periods
data_P1P2$Period[data_P1P2$ifbluurhok %in% both_periods_quadrants] <- "Both"

# Create the colour column based on the updated Period column
data_P1P2$colour <- ifelse(data_P1P2$Period == "Period 1", "blue",
                           ifelse(data_P1P2$Period == "Period 2", "red",
                                  ifelse(data_P1P2$Period == "Both", "purple", NA)))

p <- ggplot(data_P1P2) +
  geom_sf(aes(geometry = geometry, fill = colour), size = 5, color = "black") +
  scale_fill_manual(values = c("blue" = "blue", "red" = "red", "purple" = "purple"), guide = guide_legend(title = "Period")) +
  geom_polygon(data = Vlaanderen, aes(x = long, y = lat, group = group), fill = "transparent") +
  geom_path(data = Vlaanderen, aes(x = long, y = lat, group = group), colour = "black") +
  geom_polygon(data = Hoofdrivieren, aes(x = long, y = lat, group = group), fill = "transparent") +
  geom_path(data = Hoofdrivieren, aes(x = long, y = lat, group = group), colour = "blue") +
  coord_sf() +
  theme_bw()
p
ggsave(paste(n, "_both.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/Alldata_Funbel")

colnames(xyP1)[2] <- "nSpecsP1"
colnames(xyP2)[2] <- "nSpecsP2"
xyP1 <- xyP1[, -9]
xyP2 <- xyP2[, -9]

#### Plot of observations shared between both periods (1800-2023) [Plot 6] ####
nSpecsP1P2 <- full_join(nSpecsIFBLP1,
                        nSpecsIFBLP2,
                        by = "ifbluurhok")
head(nSpecsP1P2)

# Substitute "NA" by 0
nSpecsP1P2 <- nSpecsP1P2 %>%
  replace(is.na(.), 0)
head(nSpecsP1P2)

fullP1 <- full_join(P1,
                    nSpecsIFBLP1,
                    by = "ifbluurhok")
fullP1

fullP2 <- full_join(P2,
                    nSpecsIFBLP2,
                    by = "ifbluurhok")
fullP2

# Make a file of quadrants in which a minimum number of species were observed in both periods
setMin <- 5

Gem1 <- fullP1 %>% 
  group_by(ifbluurhok,
           nSpecsP1) %>% 
  filter(nSpecsP1 >= setMin) %>% 
  summarise(count2 = n())
Gem1

Gem2 <- fullP2 %>% 
  group_by(ifbluurhok,
           nSpecsP2) %>% 
  filter(nSpecsP2 >= setMin) %>% 
  summarise(count2 = n())
Gem2

# Common quadrants counted in both period
Gem12 <- inner_join(Gem1,
                    Gem2,
                    by = "ifbluurhok")
Gem12

# Plot the jointly surveyed quadrants in both period
xyGem12 <- inner_join(Gem12,
                      xyIFBLuursf,
                      by = "ifbluurhok")
head(xyGem12)

p <- ggplot(xyGem12) +
  geom_sf(aes(geometry = geometry)) +
  geom_polygon(data = Vlaanderen,
               aes(x = long,
                   y=lat,
                   group = group),
               fill = "transparent") +
  geom_path(data = Vlaanderen,
            aes(x = long,
                y = lat,
                group = group),
            colour = "black") +
  geom_polygon(data = Hoofdrivieren,
               aes(x = long,
                   y = lat,
                   group = group),
               fill = "transparent") +
  geom_path(data = Hoofdrivieren,
            aes(x = long,
                y = lat,
                group = group),
            colour = "blue") +
  coord_sf() +
  theme_bw() 
p
ggsave(paste(n, "_shared_observations.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/Alldata_Funbel")

#### Well-surveyed eco-districts [Plot 7] ####

# Count the number of surveyed ifbl1km quadrants for each eco-district
nIFBLEcodistrictData <- inner_join(Gem12,
                                   ecoVL,
                                   by = "ifbluurhok")
head(nIFBLEcodistrictData)
nrow(nIFBLEcodistrictData)

# Number of surveyed ifbl1km-quadrants à eco-district
nIFBLEcodistrictData <- nIFBLEcodistrictData %>% 
  group_by(Ecodistrict) %>% 
  summarise(nIFBL = n())	
head(nIFBLEcodistrictData)

# Total number of ifbl1km-quadrants surveyed à eco-district
nIFBLEcodistrict <- ecoVL %>% 
  group_by(Ecodistrict) %>% 
  summarise(nIFBL = n())	
head(nIFBLEcodistrict)

percEcodistrict <- full_join(nIFBLEcodistrictData,
                             nIFBLEcodistrict,
                             by = "Ecodistrict")
percEcodistrict

percEcodistrict <- percEcodistrict %>% 
  rename(nIFBLData = nIFBL.x,
         nIFBLEcodistrict = nIFBL.y)
head(percEcodistrict)

percEcodistrict <- percEcodistrict %>% 
  group_by(Ecodistrict) %>% 
  summarise(nIFBLData = mean(nIFBLData),
            nIFBLEcodistrict = mean(nIFBLEcodistrict),
            percOnderzocht = round(100*nIFBLData/nIFBLEcodistrict, 2))
head(percEcodistrict)

# At least 20% of the ifbl1km-quadrants of an eco-district must be surveyed in order to be considered as a well-surveyed eco-district
percEcodistrict$Onderzocht <- ifelse(percEcodistrict$percOnderzocht >= 5,
                                     "1. Voldoende",
                                     "2. Onvoldoende")

write.table(percEcodistrict, "percentageOnderzochEcodistrict.csv",
            row.names = FALSE,
            sep = ";",
            dec = ".")

percEcodistrictJoin <- inner_join(shapeEcoVLsf,
                                  percEcodistrict,
                                  by = "Ecodistrict")

# Substitute "NA" by 0
percEcodistrictJoin$Onderzocht[is.na(percEcodistrictJoin$Onderzocht)] <- "3. Geen data"
percEcodistrictJoin$percOnderzocht[is.na(percEcodistrictJoin$percOnderzocht)] <- 0
head(percEcodistrictJoin)

colours = c("1. Voldoende" = "darkgreen",
            "2. Onvoldoende" = "red",
            "3. Geen data" = "grey")

p <- ggplot(percEcodistrictJoin) +
  geom_sf(aes(fill = Onderzocht),
          colour = "white") +
  scale_fill_manual(values = colours) +
  theme_bw() +
  ggtitle("Funbel") +
  theme(plot.title = element_text(hjust = 0.5))
p
ggsave(paste(n, "_ecodistricten.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/Alldata_Funbel")

#### Criterion A ####
####Loading in the data####
condensAllVL <- condensAllVL[, c('Species', 'ifbluurhok', 'Year', 'Nednaam')]

####Create a new dataframe specifying the number of ifbl1km-quadrants observed for each species for both studied periods####
BT <- condensAllVL %>% 
  distinct(Species,
           Year,
           ifbluurhok) %>% 
  filter(Year >= 1800 & Year <= 2023) %>% 
  mutate(period = case_when(Year >= 1800 & Year <= 2000 ~ "p1800_2000",
                            Year >= 2001 & Year <= 2023 ~ "p2001_2023")) %>%  
  distinct(Species,
           ifbluurhok,
           period) %>% 
  group_by(Species,
           period) %>% 
  summarise(n_hokken = n())
BT

BT_wide <- BT %>% 
  pivot_wider(id_cols = Species,
              names_from = period,
              values_from = n_hokken)
BT_wide

#If a species was not observed in one or both periods then Rstudio displays "NA". 
BT_wide[c("p1800_2000", "p2001_2023")][is.na(BT_wide[c("p1800_2000", "p2001_2023")])] <- 0

#### Creating a subset of BT_wide ####
#Keep only species that were observed in at least 5 quadrants in either of both periods 
BT_wide_ED <- BT_wide %>% 
  filter(p1800_2000 >= 5 | p2001_2023 >= 5)
BT_wide_DD <- BT_wide %>%
  filter(p1800_2000 < 5 & p2001_2023 < 5)
BT_wide_RE <- BT_wide %>%
  filter(p1800_2000 > 0 & p2001_2023 == 0)
BT_wide_ED
BT_wide_DD
BT_wide_RE
#Save file BT_wide
write_delim(BT_wide,
            "/scratch/gent/469/vsc46998/BT_wide.csv",
            delim = ";")
# For some species we do not calculate a trend because they are too common.
sum(BT_wide_ED$p1800_2000) #Calculate the total sum of the sampled quadrants across all species in period 1
sum(BT_wide_ED$p2001_2023) #Calculate the total sum of the sampled quadrants across all species in period 2
max(BT_wide_ED$p1800_2000) #381:The max number of quadrants that was observed for a single species in period 1
max(BT_wide_ED$p2001_2023) #792:The max number of quadrants that was observed for a single species in period 2

BT_wide_sum <- BT_wide_ED %>% 
  mutate(sum = p1800_2000 + p2001_2023,
         percP1800_2000 = 100* p1800_2000/max(BT_wide_ED$p1800_2000),
         percP2001_2023 = 100* p2001_2023/max(BT_wide_ED$p2001_2023))
BT_wide_sum
noTrendSpecs <- BT_wide_sum %>% 
  mutate(noTrend = case_when(percP1800_2000 >= 75 & percP2001_2023 >= 75 ~ "noTrend"),
         noTrend = replace_na(noTrend, "Trend"))
noTrendSpecs
write_delim(noTrendSpecs,
            "/scratch/gent/469/vsc46998/noTrendSpecs.csv",
            delim = ";")

BT_wide_sum <- BT_wide_sum %>% 
  filter(p1800_2000 >= 0 & p2001_2023 >= 0)
BT_wide_sum

nSpecsAnalysis <- BT_wide_sum %>% 
  filter(p1800_2000 >= 5 | p2001_2023 >= 5)
nrow(nSpecsAnalysis)
#### Calculation of trend ####
BTH <- BT_wide_sum %>%
  mutate(p2001_2023 = ifelse(p1800_2000 == 0 & p2001_2023 == 0, NA, p2001_2023)) %>%
  pivot_longer(cols = c(p1800_2000:p2001_2023),
               names_to = "periode",
               values_to = "n_hokken") %>%
  group_by(periode) %>%
  filter(!is.na(n_hokken)) %>%
  mutate(rel_abun = ifelse(periode == "p1800_2000", (n_hokken) / P1_count, (n_hokken) / P2_count)) %>% 
  ungroup() %>%
  pivot_wider(id_cols = Species,
              names_from = periode,
              values_from = rel_abun) %>%
  pivot_longer(cols = c(p2001_2023),
               names_to = "periode",
               values_to = "rel_abun") %>%
  filter(!is.na(rel_abun)) %>%
  mutate(si = rel_abun / p1800_2000,
         log_si = log(si),
         trend = 100 * exp(log_si) - 100) #Historische trend
BTH

# Assuming species column exists in both BTH and BT_wide_sum
inf_species <- BTH$Species[BTH$trend == Inf] # Extract species with "Inf" trend
# Calculate new trend for each species with "Inf" trend
new_trend <- BT_wide_sum$p2001_2023[match(inf_species, BT_wide_sum$Species)] * 100
# Update "Inf" values in the trend column with the new trend values
BTH$trend[BTH$trend == Inf] <- new_trend
BTH

#Calculation of recent trend
BTH <- inner_join(BTH,
                  noTrendSpecs,
                  by = "Species")
BTH

write_delim(BTH,
            "/scratch/gent/469/vsc46998/RLCFlanders_CriterionA_SpeciesIndex.csv",
            delim = ";")

critA_SI <- BTH %>% 
  dplyr::select(Species,
                trend,
                noTrend, 
                sum) %>% 
  rename(trend_SI = trend)
critA_SI

write_delim(critA_SI,
            "/scratch/gent/469/vsc46998/critA_SI.csv",
            delim = ";")
#### Determining Red List Category ####
critA_SI <- critA_SI %>%
  mutate(RLC_A_SI = case_when(trend_SI <= -80  ~ "CR",
                              (trend_SI <= -50 & trend_SI > -80) ~ "EN",
                              (trend_SI <= -30 & trend_SI > -50) ~ "VU",
                              (trend_SI < 0 & trend_SI > -30) & sum > 10 ~ "LC",
                              (trend_SI < 0 & trend_SI > -30) & sum <= 10 ~ "NT",
                              trend_SI >= 0 ~ "LC"))
critA_SI <- critA_SI %>%
  select(-sum)

#Assigning Red List Categories DD and RE 
species_in_BT_wide_RE <- BT_wide_RE$Species
BT_wide_DD <- BT_wide_DD %>%
  mutate(trend_SI = NA,
         noTrend = "noTrend",
         RLC_A_SI = "DD") %>%
  select(Species, trend_SI, noTrend, RLC_A_SI)
critA_SI <- rbind(critA_SI, BT_wide_DD)
critA_SI <- critA_SI %>%
  mutate(RLC_A_SI = ifelse(Species %in% species_in_BT_wide_RE, "RE", RLC_A_SI))

Lat_Ned <- read_excel("Lat_Ned.xlsx")
Publish <- read_excel("species_info_publication_GBIF.xlsx")
critA_SI <- merge(critA_SI, Lat_Ned, by = "Species", all.x = TRUE)
critA_SI <- merge(critA_SI, Publish, by = "Species", all.x = TRUE)
write.xlsx(critA_SI,
           "/data/gent/vo/001/gvo00142/vsc46998/critA_SI.xlsx",
           rowNames = FALSE)
critA_SI
#### Criterion B ####
#### Read in the data ####
condensAll2023 <- condensAllVL[, c('Species', 'ifbluurhok', 'Year', 'Nednaam')]
condensAll2023$Year <- as.numeric(condensAll2023$Year)

#### AoO based on ifbl1km ####
#2001-2023 (AoO - Area of Occupancy)
AoO_Ifbl4km_2001_2023 <- condensAll2023 %>%
  filter(condensAll2023$Year >= 2001)
AoO <- AoO_Ifbl4km_2001_2023 %>% 
  distinct(Species,
           ifbluurhok) %>% 
  group_by(Species) %>% 
  count()%>% 
  summarise(AoO = n * 1)
AoO

#### B2ai (Strong fragmentation) ####
ecoVL_B2ai <- ecoVL %>%
  select(IFBL, ifbluurhok, Xcoord, Ycoord) %>%
  rename(IFBLuur = IFBL)
condensAllVL_B2ai <- inner_join(ecoVL_B2ai,
                                condensAll2023,
                                by = "ifbluurhok")
# Load your observation data
observations <- condensAllVL_B2ai %>%
  filter(condensAllVL_B2ai$Year >= 2001)
# Load the ecodistrict shapefile
ecodistrict <- st_read("/data/gent/469/vsc46998/ecodistrict2002.shp")
# Set the CRS for ecodistrict, assuming it's necessary
ecodistrict <- st_set_crs(ecodistrict, 31370)
# Load the grid shapefile
grid <- st_read("/data/gent/469/vsc46998/ifbl01x01.shp")
# Transform ecodistrict CRS to match grid CRS if they are different
if (!identical(st_crs(ecodistrict)$proj4string, st_crs(grid)$proj4string)) {
  ecodistrict <- st_transform(ecodistrict, st_crs(grid))
}
# Check the CRS of ecodistrict and print
observations <- observations %>%
  select(-Xcoord, -Ycoord)
# Merge grid data with observations to update the correct geometry
observations <- observations %>%
  left_join(grid %>% select(Name,Xcoord,Ycoord), by = c("ifbluurhok" = "Name"))
observations_sf <- st_as_sf(observations, crs = st_crs(grid))
analyze_species_distribution <- function(species_name) {
  species_observations <- observations_sf %>%
    filter(Species == species_name) %>%
    st_geometry()
  buffer_10km <- st_buffer(species_observations, dist = 10000)
  separate_polygons <- st_union(buffer_10km)
  # Ensure that non-overlapping polygons are treated as separate entities
  separate_polygons <- st_cast(separate_polygons, "POLYGON")
  polygon_areas <- st_area(separate_polygons) / 10^6  # Convert to km²
  polygon_areas_numeric <- as.numeric(polygon_areas)
  fragmented <- length(polygon_areas_numeric) > 2 & all(polygon_areas_numeric < 5000)
  total_area <- sum(polygon_areas_numeric)
  num_polygons <- length(polygon_areas_numeric)  # This now correctly reflects non-overlapping polygons
  metrics <- tibble(
    Species = species_name,
    Number_of_Polygons = num_polygons,
    Total_Area_km2 = total_area,
    Fragmented = fragmented
  )
  plot_title <- paste("Distribution for", species_name, ifelse(fragmented, " - Fragmented", ""))
  plot_colors <- if (fragmented) "yellow" else "grey"
  plot <- ggplot() +
    geom_sf(data = ecodistrict, fill = "lightblue", color = "grey", size = 0.2) +
    geom_sf(data = grid, fill = NA, color = "grey", size = 0.2) +
    geom_sf(data = st_as_sf(separate_polygons), fill = plot_colors, color = "blue", alpha = 0.5) +
    labs(title = plot_title)
  list(Plot = plot, Metrics = metrics)
}
# Initialize an empty list to store metrics for all species
species_metrics_list <- list()
species_list <- unique(observations_sf$Species)
# Apply the function to each species and store results
for (species_name in species_list) {
  result <- analyze_species_distribution(species_name)
  print(result$Plot)
  plot_filename <- paste0(species_name, "_distribution_plot.png")
  ggsave(file.path("/data/gent/vo/001/gvo00142/vsc46998/Funbel_Fragmented_Without_EoO_2", plot_filename), result$Plot, width = 8, height = 6, units = "in", dpi = 300)
  # Add the metrics for this species to the list
  species_metrics_list[[species_name]] <- result$Metrics
}
# Combine all metrics into a single DataFrame
all_species_metrics <- bind_rows(species_metrics_list, .id = "Species_Name")
head(all_species_metrics)

#### B2biv (Continuing decline in number of locations) ####

B2biv_2001_2022 <- condensAll2023 %>%
  filter(condensAll2023$Year >= 2001 & condensAll2023$Year <= 2022)

unique_species <- unique(B2biv_2001_2022$Species)
unique_species_list <- as.list(unique_species)

B2biv <- data.frame(Species = character(),
                    Slope = numeric(),
                    R_squared = numeric(),
                    stringsAsFactors = FALSE) 
Year_list <- unique(B2biv_2001_2022$Year)
values <- numeric(length(Year_list))
B2biv_distinct <- B2biv_2001_2022 %>%
  distinct(Species,ifbluurhok,Year)
for (i in 1:length(Year_list)) {
  year <- Year_list[[i]]
  group <- B2biv_distinct[B2biv_distinct$Year == year,]
  group <- group %>%
    group_by(Species) %>%
    count() %>%
    summarise(n = n)
  values[i] <- max(group$n)
}
data <- data.frame(Year = Year_list, n = values)
# Iterate over each species
for (i in 1:length(unique_species_list)) {
  spec <- unique_species_list[[i]]  # Corrected
  # Create a subset of your data for the current species
  group <- B2biv_distinct[B2biv_distinct$Species == spec, ]
  # Get observations and corresponding years
  years <- group %>%
    group_by(Year) %>%
    count() %>%
    summarise(n = n)  # Count observations per year
  years <- merge(years, data, by = "Year")
  # Perform division
  years$n <- years$n.x / years$n.y
  # Drop unnecessary column
  years <- years[, -which(names(years) %in% c("n.y", "n.x"))]
  # Perform linear regression
  regression <- lm(n ~ Year, data = years)
  # Extract slope and R-squared value
  slope <- coef(regression)[2]
  r_squared <- summary(regression)$r.squared
  
  # Append results to data frame
  new_row <- data.frame(Species = spec, Slope = slope, R_squared = r_squared)
  B2biv <- rbind(B2biv, new_row)
}
B2biv
B2biv <- B2biv %>%
  mutate('b(iv)' = case_when(Slope < 0 & R_squared >= 0.5 ~ 1,
                             Slope > 0 & R_squared >= 0.5 ~ 0,
                             TRUE ~ NA_real_))

critB <- AoO
critB

#### Creat joined file of all B2_subcriteria ####

selected_all_species_metrics <- select(all_species_metrics, Species, Fragmented) 
selected_all_species_metrics <- selected_all_species_metrics %>%
  mutate('a(i)' = ifelse(Fragmented == TRUE, 1, 0))
selected_all_species_metrics <- selected_all_species_metrics %>%
  select(-Fragmented)
selected_B2biv <- select(B2biv, Species, 'b(iv)')
joined_data <- left_join(selected_all_species_metrics, selected_B2biv, by = "Species")

#### Assigning the Red Rist Classes ####

critBab <-joined_data

critBab$`a(i)` <- as.numeric(critBab$`a(i)`)
critBab$`b(iv)` <- as.numeric(critBab$`b(iv)`)

critBab <- critBab %>% 
  replace(is.na(.), 2)
critB <- inner_join(critB,
                    critBab,
                    by = "Species")

critB <- critB %>% 
  replace(is.na(.), 2)

critB <- critB %>% 
  mutate(a = case_when(`a(i)` == 1 ~ 1,
                       TRUE ~ 0),
         b = case_when(`b(iv)` == 1 ~ 1,
                       TRUE ~ 0)) %>% 
  replace(is.na(.), 0) %>% 
  mutate(ab = a + b)

critB <- critB %>% 
  mutate(RLC_B_AoO = case_when(AoO == 0 ~ "RE",
                               AoO == 1 ~ "CR",
                               (AoO >= 2 & AoO <= 5) & ab >= 1 ~ "CR",
                               (AoO >= 2 & AoO <= 5) & ab == 0 ~ "EN",
                               (AoO >= 6 & AoO <= 10) & ab >= 1  ~ "EN",
                               (AoO >= 6 & AoO <= 10) & ab == 0 ~ "VU",
                               (AoO >= 11 & AoO <= 50) & ab >= 1 ~ "VU",
                               (AoO >= 11 & AoO <= 50) & ab == 0 ~ "NT",
                               AoO > 50 & ab >= 1 ~ "NT"),
         RLC_B_AoO = replace_na(RLC_B_AoO, "LC"))


critB <- critB %>% 
  dplyr::select(Species,
                `a(i)`,
                AoO,
                `b(iv)`,
                ab,
                RLC_B_AoO)

critB <- critB %>%
  rename(RLC_B = RLC_B_AoO)

head(critB)

Masterlist <- right_join(critB,
                         critA_SI,
                         by = "Species")
Masterlist$RLC_A_SI <- ifelse(is.na(Masterlist$RLC_A_SI), "DD", Masterlist$RLC_A_SI)
Masterlist <- Masterlist %>%
  mutate(Final_RLC = case_when(RLC_B == "RE" | RLC_A_SI == "RE" ~ "RE",
                               RLC_B == "CR" | RLC_A_SI == "CR" ~ "CR", 
                               RLC_B == "EN" | RLC_A_SI == "EN" ~ "EN", 
                               RLC_B == "VU" | RLC_A_SI == "VU" ~ "VU",
                               RLC_B == "NT" | RLC_A_SI == "NT" ~ "NT",
                               RLC_B == "LC" | RLC_A_SI == "LC" ~ "LC",
                               RLC_B == "DD" | RLC_A_SI == "DD" ~ "DD"))
Masterlist <- Masterlist %>%
  mutate(GENUS = word(Species, 1, sep = " "))
FungalTraits <- read_excel("FungalTraits.xlsx")
FungalTraits <- FungalTraits %>%
  select(GENUS, Family, Order)
Masterlist <- left_join(Masterlist,
                        FungalTraits,
                        by = "GENUS")
Masterlist <- Masterlist %>%
  mutate(Family = ifelse(GENUS == "Dissingia", "Helvellaceae", Family),
         Order  = ifelse(GENUS == "Dissingia", "Pezizales", Order),
         Family = ifelse(GENUS == "Collybiopsis", "Marasmiaceae", Family),
         Order  = ifelse(GENUS == "Collybiopsis", "Agaricales", Order))
#### Saving files in directory ####
write.xlsx(joined_data, "/data/gent/vo/001/gvo00142/vsc46998/joined_data_Funbel_v8.xlsx", rowNames = FALSE)
write.xlsx(critB,
           "/data/gent/vo/001/gvo00142/vsc46998/Funbel_critB_withRL_without_EoO_v8.xlsx", rowNames = FALSE)
write.xlsx(Masterlist,
           "/data/gent/vo/001/gvo00142/vsc46998/Funbel_Masterlist_without_EoO_v8.xlsx", rowNames = FALSE)

#### Natuurpunt ####
#### Read in the data ####
xlsx1 <- read_excel("xlsx1.xlsx")
xlsx2 <- read_excel("xlsx2.xlsx")
xlsx3 <- read_excel("xlsx3.xlsx", col_types = c("numeric", 
                                                "text", "text", "numeric", "date", "date", 
                                                "numeric", "text", "text", "text", "text", 
                                                "numeric", "numeric", "numeric", "numeric", 
                                                "text", "text", "text", "text", "text", 
                                                "text", "text", "date", "numeric", "text", 
                                                "numeric", "text", "text", "date", "numeric", 
                                                "text"))
xlsx4 <- read_excel("xlsx4.xlsx", col_types = c("numeric", 
                                                "text", "text", "numeric", "date", "date", 
                                                "numeric", "text", "text", "text", "text", 
                                                "numeric", "numeric", "numeric", "numeric", 
                                                "text", "text", "text", "text", "text", 
                                                "text", "text", "date", "numeric", "text", 
                                                "numeric", "text", "text", "date", "numeric", 
                                                "text"))
# Combining the 4 different datasets coming from waarnemingen.be
combined_data <- bind_rows(xlsx3, xlsx4, xlsx1, xlsx2)

#### Taxonomic correction ####
Natuurpunt_taxa <- read_excel("Natuurpunt_taxa.xlsx", 
                              sheet = "herleide lijst")

subset_Natuurpunt_data <- combined_data %>%
  filter(naam_lat %in% Natuurpunt_taxa$naam_lat)
subset_Natuurpunt_taxa <- Natuurpunt_taxa[, !(names(Natuurpunt_taxa) %in% "naam_nl")]

#Updating the Latin names 
merged_data <- merge(subset_Natuurpunt_data, subset_Natuurpunt_taxa, by = "naam_lat", all.x = TRUE)
merged_data$naam_lat <- ifelse(merged_data$naam_lat != merged_data$updated_name, merged_data$updated_name, merged_data$naam_lat)
merged_data <- merged_data[, !(names(merged_data) %in% c("updated_name"))]
merged_data$naam_lat <- gsub("Xerocomus rubellus", "Hortiboletus rubellus", merged_data$naam_lat)
merged_data$naam_lat <- gsub("Xerocomellus rubellus", "Hortiboletus rubellus", merged_data$naam_lat)
merged_data$naam_lat <- gsub("Xerocomus rubellus s\\.l\\.", "Hortiboletus rubellus s.l.", merged_data$naam_lat, fixed = TRUE)
merged_data$naam_lat <- gsub("Xerocomellus rubellus s\\.l\\.", "Hortiboletus rubellus s.l.", merged_data$naam_lat, fixed = TRUE)
merged_data$naam_lat <- gsub("Pulveroboletus gentilis", "Aureoboletus gentilis", merged_data$naam_lat)
merged_data$naam_lat <- gsub("Russula olivaceoviolascens", "Russula atrorubens", merged_data$naam_lat)
merged_data$naam_lat <- gsub("Microglossum atropurpureum", "Geoglossum atropurpureum", merged_data$naam_lat)
merged_data$naam_lat <- gsub("Russula emeticella", "Russula silvestris", merged_data$naam_lat)
merged_data$naam_lat <- gsub("Xerocomellus armeniacus", "Rheubarbariboletus armeniacus", merged_data$naam_lat)

#### Transforming mapping system ####
subset_Natuurpunt_data <- merged_data %>%
  mutate(lon_original = lon, lat_original = lat)
points_sf <- st_as_sf(subset_Natuurpunt_data, coords = c('lon', 'lat'), crs = 4326)

# "UURHOKKEN" using shapefile 

# Load IFBL grid shape file (update the path to your shape file)
ifbl_grid <- st_read("ifbl04x04.shp")
# Transform the points to the same CRS as IFBL grid
points_transformed <- st_transform(points_sf, st_crs(ifbl_grid))
# Spatial join: match each point with the IFBL grid square it falls into
joined_data <- st_join(points_transformed, ifbl_grid)
# Convert joined data back to a regular data frame
data_ifbl <- as.data.frame(joined_data)

# "KWARTIERHOKKEN" using kml file

# Load IFBL grid KML file (update the path to your KML file)
ifbl_grid_kml <- st_read('IFBL_kwartierhokken.kml')
# Spatial join: match each point with the IFBL grid square it falls into
joined_data <- st_join(points_sf, ifbl_grid_kml)
# Convert joined data back to a regular data frame
df_joined <- as.data.frame(joined_data)
# Rename 'Name' column to 'IFBL_kwartier' and drop 'Description' column
data_ifbl <- df_joined %>%
  rename(IFBL_kwartier = Name) %>%
  select(-Description, -geometry)
# Save the result
write.csv2(df_joined, 'data_with_IFBL_squares.csv')


#### Adding and Renaming columns ####
#Adding
data_ifbl <- data_ifbl %>%
  mutate(
    Year = ifelse(
      !is.na(as.Date(datum, format = "%Y-%m-%d", errors = "coerce")),
      as.integer(format(as.Date(datum, format = "%Y-%m-%d"), "%Y")),
      as.integer(str_extract(datum, "^\\d{4}"))
    )
  )
data_ifbl$Year <- as.numeric(data_ifbl$Year) #To make sure that the Year column is regarded as a numeric value.
#Renaming
data_ifbl<- data_ifbl%>% 
  dplyr::rename(Species = naam_lat) #To rename the first column to Species.
data_ifbl<- data_ifbl%>% 
  dplyr::rename(ifbluurhok = IFBL_kwartier)
head(data_ifbl)
nrow(data_ifbl) #The number of observations in the initial file.

#### Removing non-validated observations ####
unwanted_statuses <- c("In behandeling", "Onbehandeld", "Niet te beoordelen", "Niet goedgekeurd", "NA")
# Use subset to filter out rows with unwanted statuses
data_ifbl <- subset(data_ifbl, !(status %in% unwanted_statuses))

#### Visualising the data ####
n <- "Alldata_Natuurpunt"

# Make a condensed table
condensAllRecordsPerJaar <- data_ifbl%>% 
  filter(Year >= 1800) %>% 
  group_by(Year) %>%  
  summarise(count = n())
head(condensAllRecordsPerJaar)  

# join both files with only the Flemish ifbl1km-quadrants 
condensAllVL <- inner_join(data_ifbl,
                           provVL,
                           by = "ifbluurhok")
head(condensAllVL)
nrow(condensAllVL)

#### Condensed observations à Year [Plot 1] ####

# Plot the number of condensed observations à year
condensAllRecordsPerJaar_Natuurpunt <- condensAllRecordsPerJaar
p <- ggplot(condensAllRecordsPerJaar,
            aes(x = Year,
                y = count)) +
  geom_col() +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45,
                                   hjust = 1)) +
  ggtitle("Funbel & Natuurpunt Combined") + xlab("Year") + ylab("Number of condensed observations à year") +
  theme(plot.title = element_text(hjust = 0.5))
p
ggsave(paste(n, "_gegevens_per_jaar.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/Alldata_Natuurpunt")

#### Condensed observations à Year (>= 1980) [Plot2] ####
condensAllRecordsPerJaar2 <- condensAllRecordsPerJaar %>% 
  filter(Year >= 1980)

p <- ggplot(condensAllRecordsPerJaar2,
            aes(x = Year,
                y = count)) +
  geom_col() +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45,
                                   hjust = 1)) +
  geom_hline(yintercept = 100,
             colour = "darkgreen",
             size = 1)
p
ggsave(paste(n, "_gegevens_per_jaar_vanaf1980.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/Alldata_Natuurpunt")
#### Ifbl1km-quadrants surveyed in period 1 (1800-2000) [Plot3] ####

# Establish period 1
beginjaarP1 <- 1800
eindjaarP1 <- 2000

# Filter data from period 1
P1 <- condensAllVL %>% 
  filter(Year >= beginjaarP1 & Year <= eindjaarP1) %>% 
  dplyr::select(Species,
                ifbluurhok) %>% 
  group_by(Species,
           ifbluurhok) %>% 
  summarise()
head(P1)
nrow(P1)
unique_ifbl <- unique(P1$ifbluurhok)
P1_count <- as.numeric(length(unique_ifbl))

# Condens and count the number of observed species for each ifbl1km-quadrant in period 1
nSpecsIFBLP1 <- P1 %>%
  group_by(ifbluurhok) %>% 
  summarise(nSpecsP1 = n())
head(nSpecsIFBLP1)

# Plot the number of observed species for each ifbl1km-quadrant 
xyP1 <- inner_join(nSpecsIFBLP1,
                   xyIFBLuursf,
                   by = "ifbluurhok")
head(xyP1)

p <- ggplot(xyP1) +
  geom_sf(aes(geometry = geometry),
          size = 5) +
  scale_colour_gradient(low = "yellow",
                        high  = "darkgreen") +
  geom_polygon(data = Vlaanderen,
               aes(x = long,
                   y = lat,
                   group = group),
               fill = "transparent") +
  geom_path(data = Vlaanderen,
            aes(x = long,
                y = lat,
                group = group),
            colour = "black") +
  geom_polygon(data = Hoofdrivieren,
               aes(x = long,
                   y = lat,
                   group = group),
               fill = "transparent") +
  geom_path(data = Hoofdrivieren,
            aes(x = long,
                y  =lat,
                group = group),
            colour = "blue") +
  coord_sf() +
  theme_bw() 
p
ggsave(paste(n, "_periode1.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/Alldata_Natuurpunt")

#### Ifbl1km-quadrants surveyed in period 2 (2001-2023) [Plot4] ####

# Establish period 2
beginjaarP2 <- 2000
eindjaarP2 <- 2023

# Filter data for period 2
P2 <- condensAllVL %>% 
  filter(Year >= beginjaarP2 & Year <= eindjaarP2) %>% 
  dplyr::select(Species,
                ifbluurhok) %>% 
  group_by(Species,
           ifbluurhok) %>% 
  summarise()
head(P2)
nrow(P2)
unique_ifbl <- unique(P2$ifbluurhok)
P2_count <- as.numeric(length(unique_ifbl))
# Condens and count the number of observed species for each ifbl1km-quadrant in period 2
nSpecsIFBLP2 <- P2 %>% 
  group_by(ifbluurhok) %>% 
  summarise(nSpecsP2 = n())
head(nSpecsIFBLP2)

# Plot the number of observed species for each ifbl1km-quadrant in period 2
xyP2 <- inner_join(nSpecsIFBLP2,
                   xyIFBLuursf,
                   by = "ifbluurhok")
head(xyP2)

p <- ggplot(xyP2) +
  geom_sf(aes(geometry = geometry),
          size = 5) +
  scale_colour_gradient(low = "yellow",
                        high  = "darkgreen") +
  geom_polygon(data = Vlaanderen,
               aes(x = long,
                   y = lat,
                   group = group),
               fill = "transparent") +
  geom_path(data=Vlaanderen,
            aes(x = long,
                y = lat,
                group = group),
            colour = "black") +
  geom_polygon(data = Hoofdrivieren,
               aes(x = long,
                   y = lat,
                   group = group),
               fill = "transparent") +
  geom_path(data = Hoofdrivieren,
            aes(x = long,
                y = lat,
                group = group),
            colour = "blue") +
  coord_sf() +
  theme_bw() 
p
ggsave(paste(n, "_periode2.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/Alldata_Natuurpunt")

#### Combined plot of observations done in period 1 & 2 (1800-2023) [Plot5] ####

xyP1$Period <- "Period 1"
xyP2$Period <- "Period 2"
colnames(xyP1)[2] <- "nSpecs"
colnames(xyP2)[2] <- "nSpecs"
data_P1P2 <- rbind(xyP1, xyP2)
unique_quadrants <- unique(data_P1P2$ifbluurhok)
length(unique_quadrants)
# Identify quadrants present in both periods
both_periods_quadrants <- intersect(data_P1P2$ifbluurhok[data_P1P2$Period == "Period 1"],
                                    data_P1P2$ifbluurhok[data_P1P2$Period == "Period 2"])

# Assign "Both" to the Period column for quadrants present in both periods
data_P1P2$Period[data_P1P2$ifbluurhok %in% both_periods_quadrants] <- "Both"

# Create the colour column based on the updated Period column
data_P1P2$colour <- ifelse(data_P1P2$Period == "Period 1", "blue",
                           ifelse(data_P1P2$Period == "Period 2", "red",
                                  ifelse(data_P1P2$Period == "Both", "purple", NA)))

p <- ggplot(data_P1P2) +
  geom_sf(aes(geometry = geometry, fill = colour), size = 5, color = "black") +
  scale_fill_manual(values = c("blue" = "blue", "red" = "red", "purple" = "purple"), guide = guide_legend(title = "Period")) +
  geom_polygon(data = Vlaanderen, aes(x = long, y = lat, group = group), fill = "transparent") +
  geom_path(data = Vlaanderen, aes(x = long, y = lat, group = group), colour = "black") +
  geom_polygon(data = Hoofdrivieren, aes(x = long, y = lat, group = group), fill = "transparent") +
  geom_path(data = Hoofdrivieren, aes(x = long, y = lat, group = group), colour = "blue") +
  coord_sf() +
  theme_bw()
p
ggsave(paste(n, "_both.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/Alldata_Natuurpunt")

colnames(xyP1)[2] <- "nSpecsP1"
colnames(xyP2)[2] <- "nSpecsP2"
xyP1 <- xyP1[, -9]
xyP2 <- xyP2[, -9]

#### Plot of observations shared between both periods (1800-2023) [Plot 6] ####

nSpecsP1P2 <- full_join(nSpecsIFBLP1,
                        nSpecsIFBLP2,
                        by = "ifbluurhok")
head(nSpecsP1P2)

# Subsitute "NA" for 0
nSpecsP1P2 <- nSpecsP1P2 %>% 
  replace(is.na(.), 0)
head(nSpecsP1P2)

fullP1 <- full_join(P1,
                    nSpecsIFBLP1,
                    by = "ifbluurhok")
fullP1

fullP2 <- full_join(P2,
                    nSpecsIFBLP2,
                    by = "ifbluurhok")
fullP2

# Make a file with quadrants containing a minium number of species for both periods 
setMin <- 5

Gem1 <- fullP1 %>% 
  group_by(ifbluurhok,
           nSpecsP1) %>% 
  filter(nSpecsP1 >= setMin) %>% 
  summarise(count2 = n())
Gem1

Gem2 <- fullP2 %>% 
  group_by(ifbluurhok,
           nSpecsP2) %>% 
  filter(nSpecsP2 >= setMin) %>% 
  summarise(count2 = n())
Gem2

# Common quadrants counted in both period
Gem12 <- inner_join(Gem1,
                    Gem2,
                    by = "ifbluurhok")
Gem12

# Plot the commonly surveyed quadrants in both periods
xyGem12 <- inner_join(Gem12,
                      xyIFBLuursf,
                      by = "ifbluurhok")
head(xyGem12)

p <- ggplot(xyGem12) +
  geom_sf(aes(geometry = geometry)) +
  geom_polygon(data = Vlaanderen,
               aes(x = long,
                   y=lat,
                   group = group),
               fill = "transparent") +
  geom_path(data = Vlaanderen,
            aes(x = long,
                y = lat,
                group = group),
            colour = "black") +
  geom_polygon(data = Hoofdrivieren,
               aes(x = long,
                   y = lat,
                   group = group),
               fill = "transparent") +
  geom_path(data = Hoofdrivieren,
            aes(x = long,
                y = lat,
                group = group),
            colour = "blue") +
  coord_sf() +
  theme_bw() 
p 
ggsave(paste(n, "_shared_observations.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/Alldata_Natuurpunt")

#### Well-surveyed eco-districts [Plot 7] ####

# Count the number of ifbl1km-quadrants observed in each eco-district
nIFBLEcodistrictData <- inner_join(Gem12,
                                   ecoVL,
                                   by = "ifbluurhok")
head(nIFBLEcodistrictData)
nrow(nIFBLEcodistrictData)

# Number of surveyed ifbl1km-quadrants for each eco-district
nIFBLEcodistrictData <- nIFBLEcodistrictData %>% 
  group_by(Ecodistrict) %>% 
  summarise(nIFBL = n())	
head(nIFBLEcodistrictData)

# Total number of ifbl1km-quadrants for each eco-ditrict
nIFBLEcodistrict <- ecoVL %>% 
  group_by(Ecodistrict) %>% 
  summarise(nIFBL = n())	
head(nIFBLEcodistrict)

percEcodistrict <- full_join(nIFBLEcodistrictData,
                             nIFBLEcodistrict,
                             by = "Ecodistrict")
percEcodistrict

percEcodistrict <- percEcodistrict %>% 
  rename(nIFBLData = nIFBL.x,
         nIFBLEcodistrict = nIFBL.y)
head(percEcodistrict)

percEcodistrict <- percEcodistrict %>% 
  group_by(Ecodistrict) %>% 
  summarise(nIFBLData = mean(nIFBLData),
            nIFBLEcodistrict = mean(nIFBLEcodistrict),
            percOnderzocht = round(100*nIFBLData/nIFBLEcodistrict, 2))
head(percEcodistrict)

# At least 20% of ifbl1km-quadrants of an eco-district must be well-surveyed in order for an eco-district to be considered well surveyed
percEcodistrict$Onderzocht <- ifelse(percEcodistrict$percOnderzocht >= 5,
                                     "1. Voldoende",
                                     "2. Onvoldoende")

write.table(percEcodistrict, "percentageOnderzochEcodistrict.csv",
            row.names = FALSE,
            sep = ";",
            dec = ".")

percEcodistrictJoin <- inner_join(shapeEcoVLsf,
                                  percEcodistrict,
                                  by = "Ecodistrict")

# Subsitute "NA" for 0
percEcodistrictJoin$Onderzocht[is.na(percEcodistrictJoin$Onderzocht)] <- "3. Geen data"
percEcodistrictJoin$percOnderzocht[is.na(percEcodistrictJoin$percOnderzocht)] <- 0
head(percEcodistrictJoin)

colours = c("1. Voldoende" = "darkgreen",
            "2. Onvoldoende" = "red",
            "3. Geen data" = "grey")

p <- ggplot(percEcodistrictJoin) +
  geom_sf(aes(fill = Onderzocht),
          colour = "white") +
  scale_fill_manual(values = colours) +
  theme_bw()
p
ggsave(paste(n, "_ecodistricten.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/Alldata_Natuurpunt")

#### Make a combined plot of the number of condensed observations a year for both datasets ####
combined_plot <- ggplot(mapping = aes(x = Year)) +
  geom_bar(data = condensAllRecordsPerJaar_Funbel, aes(y = count, fill = "Funbel"), stat = "identity") +
  geom_bar(data = condensAllRecordsPerJaar_Natuurpunt, aes(y = count, fill = "Natuurpunt"), stat = "identity") +
  scale_fill_manual(values = c("Funbel" = "#0000FF40", "Natuurpunt" = "#FF000040"), name = "Legend", labels = c("Funbel", "Natuurpunt")) +
  labs(x = "Year", y = "Number of condensed observations à year", title = "Number of condensed observations à year for the Funbel and Natuurpunt datasets") +
  theme(legend.position = "bottom", plot.title = element_text(size = 11))+
  lims(x = c(1835, 2023))
combined_plot 

#### Natuurpunt + FUNBEL ####
#### Combining both datasets ####
subset_Alldata_Funbel <- Data_updated[, c('Species', 'ifbluurhok', 'Year', 'Nednaam')]
subset_Alldata_Natuurpunt <- data_ifbl[, c('Species', 'ifbluurhok', 'Year','naam_nl')]
subset_Alldata_Natuurpunt <- subset_Alldata_Natuurpunt %>%
  rename(Nednaam = naam_nl)
data_total <- bind_rows(subset_Alldata_Funbel, subset_Alldata_Natuurpunt)
#### Final adjustments to data ####
#Removing those Species in the Natuurpunt dataset that are not considered in the FUNBEL dataset
species_updated <- unique(Data_updated$Species)
species_ifbl <- unique(data_ifbl$Species)
species_not_in_updated <- setdiff(species_ifbl, species_updated)

not_in_up <- data_ifbl %>%
  filter(Species %in% species_not_in_updated)
not_p1 <- not_in_up %>%
  filter(Year >= 1800 & Year <= 2000)
not_p2 <- not_in_up %>%
  filter(Year >= 2001 & Year <= 2023)

data_total <- data_total %>%
  filter(!Species %in% species_not_in_updated)

#Remove sp. species from the dataset
data_total <- data_total[!grepl('sp\\.', data_total$Species, ignore.case = TRUE), ]
#Remove the s.s. from any species names that still have it
data_total <- data_total[nchar(data_total$Species) > 1, ]
data_total$Species <- gsub(' s\\.s\\.', '', data_total$Species, ignore.case = TRUE)
# Identify species with both normal and s.l. variants
species_both <- unique(sub(' s\\.l\\.$', '', data_total$Species[grep(' s\\.l\\.$', data_total$Species, ignore.case = TRUE)]))
species_both <- species_both[!species_both %in% "Lactarius aurantiacus"]
# Create a logical condition to keep rows with s.l. variant only if normal variant doesn't exist
condition <- !(data_total$Species %in% paste0(species_both, ' s.l.') & !data_total$Species %in% species_both)
# Filter the dataset based on the condition
data_total <- data_total[condition, ]

#### Visualising the data ####
n <- "data_total"

# Make a condensed table
condensAllRecordsPerJaar <- data_total %>% 
  filter(Year >= 1800) %>% 
  group_by(Year) %>% 
  summarise(count = n())  
head(condensAllRecordsPerJaar) 

# Join both files containing only the Flemish ifbl1km-quadrants
condensAllVL <- inner_join(data_total,
                           provVL,
                           by = "ifbluurhok")
head(condensAllVL)
nrow(condensAllVL)
#### Condensed observations à Year [Plot 1] ####

p <- ggplot(condensAllRecordsPerJaar,
            aes(x = Year,
                y = count)) +
  geom_col() +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45,
                                   hjust = 1)) +
  ggtitle("Funbel & Natuurpunt Combined") + xlab("Year") + ylab("Number of condensed observations à year") +
  theme(plot.title = element_text(hjust = 0.5))
p
ggsave(paste(n, "_gegevens_per_jaar.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/data_total")

#### Condensed observations à Year (>= 1980) [Plot2] ####
condensAllRecordsPerJaar2 <- condensAllRecordsPerJaar %>% 
  filter(Year >= 1980)

p <- ggplot(condensAllRecordsPerJaar2,
            aes(x = Year,
                y = count)) +
  geom_col() +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45,
                                   hjust = 1)) +
  geom_hline(yintercept = 100,
             colour = "darkgreen",
             size = 1)
p
ggsave(paste(n, "gegevens_per_jaar_vanaf1980.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/data_total")

#### Ifbl1km-quadrants surveyed in periode 1 (1800-2000) [Plot3] ####
# Establish period 1
beginjaarP1 <- 1800
eindjaarP1 <- 2000

# Filter the data from period 1
P1 <- condensAllVL %>% 
  filter(Year >= beginjaarP1 & Year <= eindjaarP1) %>% 
  dplyr::select(Species,
                ifbluurhok) %>% 
  group_by(Species,
           ifbluurhok) %>% 
  summarise()
head(P1)
nrow(P1)
unique_ifbl <- unique(P1$ifbluurhok)
P1_count <- as.numeric(length(unique_ifbl))

# Condens and count the number of observed species for each ifbl1km-quadrant in period 1
nSpecsIFBLP1 <- P1 %>%
  group_by(ifbluurhok) %>% 
  summarise(nSpecsP1 = n())
head(nSpecsIFBLP1)

# Plot the number of observed species for each ifbl1km-quadrant in period 1
xyP1 <- inner_join(nSpecsIFBLP1,
                   xyIFBLuursf,
                   by = "ifbluurhok")
head(xyP1)

p <- ggplot(xyP1) +
  geom_sf(aes(geometry = geometry),
          size = 5) +
  scale_colour_gradient(low = "yellow",
                        high  = "darkgreen") +
  geom_polygon(data = Vlaanderen,
               aes(x = long,
                   y = lat,
                   group = group),
               fill = "transparent") +
  geom_path(data = Vlaanderen,
            aes(x = long,
                y = lat,
                group = group),
            colour = "black") +
  geom_polygon(data = Hoofdrivieren,
               aes(x = long,
                   y = lat,
                   group = group),
               fill = "transparent") +
  geom_path(data = Hoofdrivieren,
            aes(x = long,
                y  =lat,
                group = group),
            colour = "blue") +
  coord_sf() +
  theme_bw() 
p
ggsave(paste(n, "_periode1.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/data_total")

#### Ifbl1km-quadrants surveyed in periode 2 (2001-2023) [Plot4] ####

# Establish period 2
beginjaarP2 <- 2001
eindjaarP2 <- 2023

# Filter the data for period 2
P2 <- condensAllVL %>% 
  filter(Year >= beginjaarP2 & Year <= eindjaarP2) %>% 
  dplyr::select(Species,
                ifbluurhok) %>% 
  group_by(Species,
           ifbluurhok) %>% 
  summarise()
head(P2)
nrow(P2)
unique_ifbl <- unique(P2$ifbluurhok)
P2_count <- as.numeric(length(unique_ifbl))
# Condens and count the number of observed species for each ifbl1km-quadrant in period 2
nSpecsIFBLP2 <- P2 %>% 
  group_by(ifbluurhok) %>% 
  summarise(nSpecsP2 = n())
head(nSpecsIFBLP2)

# Plot the number of observed species for each ifbl1km-quadrant in period 2
xyP2 <- inner_join(nSpecsIFBLP2,
                   xyIFBLuursf,
                   by = "ifbluurhok")
head(xyP2)

p <- ggplot(xyP2) +
  geom_sf(aes(geometry = geometry),
          size = 5) +
  scale_colour_gradient(low = "yellow",
                        high  = "darkgreen") +
  geom_polygon(data = Vlaanderen,
               aes(x = long,
                   y = lat,
                   group = group),
               fill = "transparent") +
  geom_path(data=Vlaanderen,
            aes(x = long,
                y = lat,
                group = group),
            colour = "black") +
  geom_polygon(data = Hoofdrivieren,
               aes(x = long,
                   y = lat,
                   group = group),
               fill = "transparent") +
  geom_path(data = Hoofdrivieren,
            aes(x = long,
                y = lat,
                group = group),
            colour = "blue") +
  coord_sf() +
  theme_bw() 
p
ggsave(paste(n, "_periode2.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/data_total")

#### Combined plot of observations done in period 1 & 2 (1800-2023) [Plot5] ####

xyP1$Period <- "Period 1"
xyP2$Period <- "Period 2"
colnames(xyP1)[2] <- "nSpecs"
colnames(xyP2)[2] <- "nSpecs"
data_P1P2 <- rbind(xyP1, xyP2)
unique_quadrants <- unique(data_P1P2$ifbluurhok)
length(unique_quadrants)
# Identify quadrants present in both periods
both_periods_quadrants <- intersect(data_P1P2$ifbluurhok[data_P1P2$Period == "Period 1"],
                                    data_P1P2$ifbluurhok[data_P1P2$Period == "Period 2"])

# Assign "Both" to the Period column for quadrants present in both periods
data_P1P2$Period[data_P1P2$ifbluurhok %in% both_periods_quadrants] <- "Both"

# Create the colour column based on the updated Period column
data_P1P2$colour <- ifelse(data_P1P2$Period == "Period 1", "blue",
                           ifelse(data_P1P2$Period == "Period 2", "red",
                                  ifelse(data_P1P2$Period == "Both", "purple", NA)))

p <- ggplot(data_P1P2) +
  geom_sf(aes(geometry = geometry, fill = colour), size = 5, color = "black") +
  scale_fill_manual(values = c("blue" = "blue", "red" = "red", "purple" = "purple"),labels = c("1800-2000 (P1)", "Visited in both periods","2001-2023 (P2)"), guide = guide_legend(title = "Period")) +
  geom_polygon(data = Vlaanderen, aes(x = long, y = lat, group = group), fill = "transparent") +
  geom_path(data = Vlaanderen, aes(x = long, y = lat, group = group), colour = "black") +
  geom_polygon(data = Hoofdrivieren, aes(x = long, y = lat, group = group), fill = "transparent") +
  geom_path(data = Hoofdrivieren, aes(x = long, y = lat, group = group), colour = "blue") +
  coord_sf() +
  theme_bw()
p
ggsave(paste(n, "_both.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/data_total")

colnames(xyP1)[2] <- "nSpecsP1"
colnames(xyP2)[2] <- "nSpecsP2"
xyP1 <- xyP1[, -9]
xyP2 <- xyP2[, -9]

#### Plot of observations shared between both periods (1800-2023) [Plot 6] ####
nSpecsP1P2 <- full_join(nSpecsIFBLP1,
                        nSpecsIFBLP2,
                        by = "ifbluurhok")
head(nSpecsP1P2)

# Substitute "NA" for 0
nSpecsP1P2 <- nSpecsP1P2 %>%
  replace(is.na(.), 0)
head(nSpecsP1P2)

fullP1 <- full_join(P1,
                    nSpecsIFBLP1,
                    by = "ifbluurhok")
fullP1

fullP2 <- full_join(P2,
                    nSpecsIFBLP2,
                    by = "ifbluurhok")
fullP2

# Make a file with quadrants contain a minimum number of species in both periods
setMin <- 5

Gem1 <- fullP1 %>% 
  group_by(ifbluurhok,
           nSpecsP1) %>% 
  filter(nSpecsP1 >= setMin) %>% 
  summarise(count2 = n())
Gem1

Gem2 <- fullP2 %>% 
  group_by(ifbluurhok,
           nSpecsP2) %>% 
  filter(nSpecsP2 >= setMin) %>% 
  summarise(count2 = n())
Gem2

# Commonly serveyed quadrants in both periods
Gem12 <- inner_join(Gem1,
                    Gem2,
                    by = "ifbluurhok")
Gem12

# Plot the commonly serveyed quadrants in both periods
xyGem12 <- inner_join(Gem12,
                      xyIFBLuursf,
                      by = "ifbluurhok")
head(xyGem12)

p <- ggplot(xyGem12) +
  geom_sf(aes(geometry = geometry)) +
  geom_polygon(data = Vlaanderen,
               aes(x = long,
                   y=lat,
                   group = group),
               fill = "transparent") +
  geom_path(data = Vlaanderen,
            aes(x = long,
                y = lat,
                group = group),
            colour = "black") +
  geom_polygon(data = Hoofdrivieren,
               aes(x = long,
                   y = lat,
                   group = group),
               fill = "transparent") +
  geom_path(data = Hoofdrivieren,
            aes(x = long,
                y = lat,
                group = group),
            colour = "blue") +
  coord_sf() +
  theme_bw() 
p
ggsave(paste(n, "_shared_observations.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/data_total")

#### Well-surveyed eco-districts [Plot 7] ####
# Count the number of ifbl1km quadrants serveyed in each eco-district
nIFBLEcodistrictData <- inner_join(Gem12,
                                   ecoVL,
                                   by = "ifbluurhok")
head(nIFBLEcodistrictData)
nrow(nIFBLEcodistrictData)

# Number of surveyed ifbl1km-quadrant in each eco-district
nIFBLEcodistrictData <- nIFBLEcodistrictData %>% 
  group_by(Ecodistrict) %>% 
  summarise(nIFBL = n())	
head(nIFBLEcodistrictData)

# Total number of surveyed ifbl1km-quadrants in each eco-district
nIFBLEcodistrict <- ecoVL %>% 
  group_by(Ecodistrict) %>% 
  summarise(nIFBL = n())	
head(nIFBLEcodistrict)

percEcodistrict <- full_join(nIFBLEcodistrictData,
                             nIFBLEcodistrict,
                             by = "Ecodistrict")
percEcodistrict

percEcodistrict <- percEcodistrict %>% 
  rename(nIFBLData = nIFBL.x,
         nIFBLEcodistrict = nIFBL.y)
head(percEcodistrict)

percEcodistrict <- percEcodistrict %>% 
  group_by(Ecodistrict) %>% 
  summarise(nIFBLData = mean(nIFBLData),
            nIFBLEcodistrict = mean(nIFBLEcodistrict),
            percOnderzocht = round(100*nIFBLData/nIFBLEcodistrict, 2))
head(percEcodistrict)

# At least 20% of the ifbl1km quadrants of an eco-district must be well-surveyed in order to consider the eco-district well-surveyed
percEcodistrict$Onderzocht <- ifelse(percEcodistrict$percOnderzocht >= 5,
                                     "1. Voldoende",
                                     "2. Onvoldoende")

write.table(percEcodistrict, "percentageOnderzochEcodistrict.csv",
            row.names = FALSE,
            sep = ";",
            dec = ".")

percEcodistrictJoin <- inner_join(shapeEcoVLsf,
                                  percEcodistrict,
                                  by = "Ecodistrict")

# Substitute "NA" for 0
percEcodistrictJoin$Onderzocht[is.na(percEcodistrictJoin$Onderzocht)] <- "3. Geen data"
percEcodistrictJoin$percOnderzocht[is.na(percEcodistrictJoin$percOnderzocht)] <- 0
head(percEcodistrictJoin)

colours = c("1. Voldoende" = "darkgreen",
            "2. Onvoldoende" = "red",
            "3. Geen data" = "grey")

p <- ggplot(percEcodistrictJoin) +
  geom_sf(aes(fill = Onderzocht),
          colour = "white") +
  scale_fill_manual(values = colours) +
  theme_bw() +
  ggtitle("Funbel & Natuurpunt Combined") +
  theme(plot.title = element_text(hjust = 0.5))
p
ggsave(paste(n, "_ecodistricten.png"), plot = p, device = "png", path = "/data/gent/vo/001/gvo00142/vsc46998/data_total")

#### Criterion A combined dataset ####
#### Loading in the data####
condensAllVL <- condensAllVL[, c('Species', 'ifbluurhok', 'Year', 'Nednaam')]

#### Create a new dataframe specifying the number of ifbl1km-quadrants observed for each species for both studied periods####
BT <- condensAllVL %>% 
  distinct(Species,
           Year,
           ifbluurhok) %>% 
  filter(Year >= 1800 & Year <= 2023) %>% 
  mutate(period = case_when(Year >= 1800 & Year <= 2000 ~ "p1800_2000",
                            Year >= 2001 & Year <= 2023 ~ "p2001_2023")) %>%  
  distinct(Species,
           ifbluurhok,
           period) %>% 
  group_by(Species,
           period) %>% 
  summarise(n_hokken = n())
BT

BT_wide <- BT %>% 
  pivot_wider(id_cols = Species,
              names_from = period,
              values_from = n_hokken)
BT_wide

#If a species was not observed in one or both periods then Rstudio displays "NA". 
BT_wide[c("p1800_2000", "p2001_2023")][is.na(BT_wide[c("p1800_2000", "p2001_2023")])] <- 0

#### Creating a subset of BT_wide ####
#Keep only species that were observed in at least 5 quadrants in either of both periods 
BT_wide_ED <- BT_wide %>% 
  filter(p1800_2000 >= 5 | p2001_2023 >= 5)
BT_wide_DD <- BT_wide %>%
  filter(p1800_2000 < 5 & p2001_2023 < 5)
BT_wide_RE <- BT_wide %>%
  filter(p1800_2000 > 0 & p2001_2023 == 0)
BT_wide_ED
BT_wide_DD
BT_wide_RE
#Save file BT_wide
write_delim(BT_wide,
            "/scratch/gent/469/vsc46998/BT_wide.csv",
            delim = ";")
# For some species we do not calculate a trend because they are too common.
sum(BT_wide_ED$p1800_2000) #Calculate the total sum of the sampled quadrants across all species in period 1
sum(BT_wide_ED$p2001_2023) #Calculate the total sum of the sampled quadrants across all species in period 2
max(BT_wide_ED$p1800_2000) #381:The max number of quadrants that was observed for a single species in period 1
max(BT_wide_ED$p2001_2023) #792:The max number of quadrants that was observed for a single species in period 2

BT_wide_sum <- BT_wide_ED %>% 
  mutate(sum = p1800_2000 + p2001_2023,
         percP1800_2000 = 100* p1800_2000/max(BT_wide_ED$p1800_2000),
         percP2001_2023 = 100* p2001_2023/max(BT_wide_ED$p2001_2023))
BT_wide_sum
noTrendSpecs <- BT_wide_sum %>% 
  mutate(noTrend = case_when(percP1800_2000 >= 75 & percP2001_2023 >= 75 ~ "noTrend"),
         noTrend = replace_na(noTrend, "Trend"))
noTrendSpecs
write_delim(noTrendSpecs,
            "/scratch/gent/469/vsc46998/noTrendSpecs.csv",
            delim = ";")

BT_wide_sum <- BT_wide_sum %>% 
  filter(p1800_2000 >= 0 & p2001_2023 >= 0)
BT_wide_sum

nSpecsAnalysis <- BT_wide_sum %>% 
  filter(p1800_2000 >= 5 | p2001_2023 >= 5)
nrow(nSpecsAnalysis)
#### Calculation of trend ####
BTH <- BT_wide_sum %>%
  mutate(p2001_2023 = ifelse(p1800_2000 == 0 & p2001_2023 == 0, NA, p2001_2023)) %>%
  pivot_longer(cols = c(p1800_2000:p2001_2023),
               names_to = "periode",
               values_to = "n_hokken") %>%
  group_by(periode) %>%
  filter(!is.na(n_hokken)) %>%
  mutate(rel_abun = ifelse(periode == "p1800_2000", (n_hokken) / P1_count, (n_hokken) / P2_count)) %>% 
  ungroup() %>%
  pivot_wider(id_cols = Species,
              names_from = periode,
              values_from = rel_abun) %>%
  pivot_longer(cols = c(p2001_2023),
               names_to = "periode",
               values_to = "rel_abun") %>%
  filter(!is.na(rel_abun)) %>%
  mutate(si = rel_abun / p1800_2000,
         log_si = log(si),
         trend = 100 * exp(log_si) - 100) #Historische trend
BTH

# Assuming species column exists in both BTH and BT_wide_sum
inf_species <- BTH$Species[BTH$trend == Inf] # Extract species with "Inf" trend
# Calculate new trend for each species with "Inf" trend
new_trend <- BT_wide_sum$p2001_2023[match(inf_species, BT_wide_sum$Species)] * 100
# Update "Inf" values in the trend column with the new trend values
BTH$trend[BTH$trend == Inf] <- new_trend
BTH

#Calculation of recent trend
BTH <- inner_join(BTH,
                  noTrendSpecs,
                  by = "Species")
BTH

write_delim(BTH,
            "/scratch/gent/469/vsc46998/RLCFlanders_CriterionA_SpeciesIndex.csv",
            delim = ";")

critA_SI <- BTH %>% 
  dplyr::select(Species,
                trend,
                noTrend, 
                sum) %>% 
  rename(trend_SI = trend)
critA_SI

write_delim(critA_SI,
            "/scratch/gent/469/vsc46998/critA_SI.csv",
            delim = ";")
#### Determining Red List Category ####
critA_SI <- critA_SI %>%
  mutate(RLC_A_SI = case_when(trend_SI <= -80  ~ "CR",
                              (trend_SI <= -50 & trend_SI > -80) ~ "EN",
                              (trend_SI <= -30 & trend_SI > -50) ~ "VU",
                              (trend_SI < 0 & trend_SI > -30) & sum > 10 ~ "LC",
                              (trend_SI < 0 & trend_SI > -30) & sum <= 10 ~ "NT",
                              trend_SI >= 0 ~ "LC"))
critA_SI <- critA_SI %>%
  select(-sum)

#Assigning Red List Categories DD and RE 
species_in_BT_wide_RE <- BT_wide_RE$Species
BT_wide_DD <- BT_wide_DD %>%
  mutate(trend_SI = NA,
         noTrend = "noTrend",
         RLC_A_SI = "DD") %>%
  select(Species, trend_SI, noTrend, RLC_A_SI)
critA_SI <- rbind(critA_SI, BT_wide_DD)
critA_SI <- critA_SI %>%
  mutate(RLC_A_SI = ifelse(Species %in% species_in_BT_wide_RE, "RE", RLC_A_SI))

Lat_Ned <- read_excel("Lat_Ned.xlsx")
Publish <- read_excel("species_info_publication_GBIF.xlsx")
critA_SI <- merge(critA_SI, Lat_Ned, by = "Species", all.x = TRUE)
critA_SI <- merge(critA_SI, Publish, by = "Species", all.x = TRUE)
write.xlsx(critA_SI,
           "/data/gent/vo/001/gvo00142/vsc46998/critA_SI.xlsx",
           rowNames = FALSE)
critA_SI
#### Criterion B combined dataset ####
#### Read in the data ####
condensAll2023 <- condensAllVL[, c('Species', 'ifbluurhok', 'Year', 'Nednaam')]
condensAll2023$Year <- as.numeric(condensAll2023$Year)

#### AoO based on ifbl1km ####
#2001-2023 (AoO - Area of Occupancy)
AoO_Ifbl4km_2001_2023 <- condensAll2023 %>%
  filter(condensAll2023$Year >= 2001)
AoO <- AoO_Ifbl4km_2001_2023 %>% 
  distinct(Species,
           ifbluurhok) %>% 
  group_by(Species) %>% 
  count()%>% 
  summarise(AoO = n * 1)
AoO

#### B2ai (Strong fragmentation) ####
ecoVL_B2ai <- ecoVL %>%
  select(IFBL, ifbluurhok, Xcoord, Ycoord) %>%
  rename(IFBLuur = IFBL)
condensAllVL_B2ai <- inner_join(ecoVL_B2ai,
                                condensAll2023,
                                by = "ifbluurhok")
# Load your observation data
observations <- condensAllVL_B2ai %>%
  filter(condensAllVL_B2ai$Year >= 2001)
# Load the ecodistrict shapefile
ecodistrict <- st_read("/data/gent/469/vsc46998/ecodistrict2002.shp")
# Set the CRS for ecodistrict, assuming it's necessary
ecodistrict <- st_set_crs(ecodistrict, 31370)
# Load the grid shapefile
grid <- st_read("/data/gent/469/vsc46998/ifbl01x01.shp")
# Transform ecodistrict CRS to match grid CRS if they are different
if (!identical(st_crs(ecodistrict)$proj4string, st_crs(grid)$proj4string)) {
  ecodistrict <- st_transform(ecodistrict, st_crs(grid))
}
# Check the CRS of ecodistrict and print
observations <- observations %>%
  select(-Xcoord, -Ycoord)
# Merge grid data with observations to update the correct geometry
observations <- observations %>%
  left_join(grid %>% select(Name,Xcoord,Ycoord), by = c("ifbluurhok" = "Name"))
observations_sf <- st_as_sf(observations, crs = st_crs(grid))
analyze_species_distribution <- function(species_name) {
  species_observations <- observations_sf %>%
    filter(Species == species_name) %>%
    st_geometry()
  buffer_10km <- st_buffer(species_observations, dist = 10000)
  separate_polygons <- st_union(buffer_10km)
  # Ensure that non-overlapping polygons are treated as separate entities
  separate_polygons <- st_cast(separate_polygons, "POLYGON")
  polygon_areas <- st_area(separate_polygons) / 10^6  # Convert to km²
  polygon_areas_numeric <- as.numeric(polygon_areas)
  fragmented <- length(polygon_areas_numeric) > 2 & all(polygon_areas_numeric < 5000)
  total_area <- sum(polygon_areas_numeric)
  num_polygons <- length(polygon_areas_numeric)  # This now correctly reflects non-overlapping polygons
  metrics <- tibble(
    Species = species_name,
    Number_of_Polygons = num_polygons,
    Total_Area_km2 = total_area,
    Fragmented = fragmented
  )
  plot_title <- paste("Distribution for", species_name, ifelse(fragmented, " - Fragmented", ""))
  plot_colors <- if (fragmented) "yellow" else "grey"
  plot <- ggplot() +
    geom_sf(data = ecodistrict, fill = "lightblue", color = "grey", size = 0.2) +
    geom_sf(data = grid, fill = NA, color = "grey", size = 0.2) +
    geom_sf(data = st_as_sf(separate_polygons), fill = plot_colors, color = "blue", alpha = 0.5) +
    labs(title = plot_title)
  list(Plot = plot, Metrics = metrics)
}
# Initialize an empty list to store metrics for all species
species_metrics_list <- list()
species_list <- unique(observations_sf$Species)
# Apply the function to each species and store results
for (species_name in species_list) {
  result <- analyze_species_distribution(species_name)
  print(result$Plot)
  plot_filename <- paste0(species_name, "_distribution_plot.png")
  ggsave(file.path("/data/gent/vo/001/gvo00142/vsc46998/Fragmented_Without_EoO_2", plot_filename), result$Plot, width = 8, height = 6, units = "in", dpi = 300)
  # Add the metrics for this species to the list
  species_metrics_list[[species_name]] <- result$Metrics
}
# Combine all metrics into a single DataFrame
all_species_metrics <- bind_rows(species_metrics_list, .id = "Species_Name")
head(all_species_metrics)

#### B2biv (Continuing decline in number of locations) ####

B2biv_2001_2022 <- condensAll2023 %>%
  filter(condensAll2023$Year >= 2001 & condensAll2023$Year <= 2022)

unique_species <- unique(B2biv_2001_2022$Species)
unique_species_list <- as.list(unique_species)

B2biv <- data.frame(Species = character(),
                    Slope = numeric(),
                    R_squared = numeric(),
                    stringsAsFactors = FALSE) 
Year_list <- unique(B2biv_2001_2022$Year)
values <- numeric(length(Year_list))
B2biv_distinct <- B2biv_2001_2022 %>%
  distinct(Species,ifbluurhok,Year)
for (i in 1:length(Year_list)) {
  year <- Year_list[[i]]
  group <- B2biv_distinct[B2biv_distinct$Year == year,]
  group <- group %>%
    group_by(Species) %>%
    count() %>%
    summarise(n = n)
  values[i] <- max(group$n)
}
data <- data.frame(Year = Year_list, n = values)
# Iterate over each species
for (i in 1:length(unique_species_list)) {
  spec <- unique_species_list[[i]]  # Corrected
  # Create a subset of your data for the current species
  group <- B2biv_distinct[B2biv_distinct$Species == spec, ]
  # Get observations and corresponding years
  years <- group %>%
    group_by(Year) %>%
    count() %>%
    summarise(n = n)  # Count observations per year
  years <- merge(years, data, by = "Year")
  # Perform division
  years$n <- years$n.x / years$n.y
  # Drop unnecessary column
  years <- years[, -which(names(years) %in% c("n.y", "n.x"))]
  # Perform linear regression
  regression <- lm(n ~ Year, data = years)
  # Extract slope and R-squared value
  slope <- coef(regression)[2]
  r_squared <- summary(regression)$r.squared
  
  # Append results to data frame
  new_row <- data.frame(Species = spec, Slope = slope, R_squared = r_squared)
  B2biv <- rbind(B2biv, new_row)
}
B2biv
B2biv <- B2biv %>%
  mutate('b(iv)' = case_when(Slope < 0 & R_squared >= 0.5 ~ 1,
                             Slope > 0 & R_squared >= 0.5 ~ 0,
                             TRUE ~ NA_real_))

critB <- AoO
critB

#### Creat joined file of all B2_subcriteria ####

selected_all_species_metrics <- select(all_species_metrics, Species, Fragmented) 
selected_all_species_metrics <- selected_all_species_metrics %>%
  mutate('a(i)' = ifelse(Fragmented == TRUE, 1, 0))
selected_all_species_metrics <- selected_all_species_metrics %>%
  select(-Fragmented)
selected_B2biv <- select(B2biv, Species, 'b(iv)')
joined_data <- left_join(selected_all_species_metrics, selected_B2biv, by = "Species")

#### Assigning the Red Rist Classes ####

critBab <-joined_data

critBab$`a(i)` <- as.numeric(critBab$`a(i)`)
critBab$`b(iv)` <- as.numeric(critBab$`b(iv)`)

critBab <- critBab %>% 
  replace(is.na(.), 2)
critB <- inner_join(critB,
                    critBab,
                    by = "Species")

critB <- critB %>% 
  replace(is.na(.), 2)

critB <- critB %>% 
  mutate(a = case_when(`a(i)` == 1 ~ 1,
                       TRUE ~ 0),
         b = case_when(`b(iv)` == 1 ~ 1,
                       TRUE ~ 0)) %>% 
  replace(is.na(.), 0) %>% 
  mutate(ab = a + b)

critB <- critB %>% 
  mutate(RLC_B_AoO = case_when(AoO == 0 ~ "RE",
                               AoO == 1 ~ "CR",
                               (AoO >= 2 & AoO <= 5) & ab >= 1 ~ "CR",
                               (AoO >= 2 & AoO <= 5) & ab == 0 ~ "EN",
                               (AoO >= 6 & AoO <= 10) & ab >= 1  ~ "EN",
                               (AoO >= 6 & AoO <= 10) & ab == 0 ~ "VU",
                               (AoO >= 11 & AoO <= 50) & ab >= 1 ~ "VU",
                               (AoO >= 11 & AoO <= 50) & ab == 0 ~ "NT",
                               AoO > 50 & ab >= 1 ~ "NT"),
         RLC_B_AoO = replace_na(RLC_B_AoO, "LC"))


critB <- critB %>% 
  dplyr::select(Species,
                `a(i)`,
                AoO,
                `b(iv)`,
                ab,
                RLC_B_AoO)

critB <- critB %>%
  rename(RLC_B = RLC_B_AoO)

head(critB)

Masterlist <- right_join(critB,
                         critA_SI,
                         by = "Species")
Masterlist$RLC_A_SI <- ifelse(is.na(Masterlist$RLC_A_SI), "DD", Masterlist$RLC_A_SI)
Masterlist <- Masterlist %>%
  mutate(Final_RLC = case_when(RLC_B == "RE" | RLC_A_SI == "RE" ~ "RE",
                               RLC_B == "CR" | RLC_A_SI == "CR" ~ "CR", 
                               RLC_B == "EN" | RLC_A_SI == "EN" ~ "EN", 
                               RLC_B == "VU" | RLC_A_SI == "VU" ~ "VU",
                               RLC_B == "NT" | RLC_A_SI == "NT" ~ "NT",
                               RLC_B == "LC" | RLC_A_SI == "LC" ~ "LC",
                               RLC_B == "DD" | RLC_A_SI == "DD" ~ "DD"))
Masterlist <- Masterlist %>%
  mutate(GENUS = word(Species, 1, sep = " "))
FungalTraits <- read_excel("FungalTraits.xlsx")
FungalTraits <- FungalTraits %>%
  select(GENUS, Family, Order)
Masterlist <- left_join(Masterlist,
                        FungalTraits,
                        by = "GENUS")
Masterlist <- Masterlist %>%
  mutate(Family = ifelse(GENUS == "Dissingia", "Helvellaceae", Family),
         Order  = ifelse(GENUS == "Dissingia", "Pezizales", Order),
         Family = ifelse(GENUS == "Collybiopsis", "Marasmiaceae", Family),
         Order  = ifelse(GENUS == "Collybiopsis", "Agaricales", Order))
#### Saving files in directory ####
write.xlsx(joined_data, "/data/gent/vo/001/gvo00142/vsc46998/joined_data_v8.xlsx", rowNames = FALSE)
write.xlsx(critB,
           "/data/gent/vo/001/gvo00142/vsc46998/critB_withRL_without_EoO_v8.xlsx", rowNames = FALSE)
write.xlsx(Masterlist,
           "/data/gent/vo/001/gvo00142/vsc46998/Masterlist_without_EoO_v8.xlsx", rowNames = FALSE)
#### Making a combined Masterlist ####
Masterlist_without_EoO <- read_excel("Masterlist_without_EoO_v8.xlsx")
Funbel_Masterlist_without_EoO <- read_excel("Funbel_Masterlist_without_EoO_v8.xlsx")
Masterlist_without_EoO_sub <- Masterlist_without_EoO %>%
  select(Species, Final_RLC) %>%
  rename(Final_RLC_NATFUN = Final_RLC)
Funbel_Masterlist_without_EoO_sub <- Funbel_Masterlist_without_EoO %>%
  select(Species, Final_RLC) %>%
  rename(Final_RLC_Funbel = Final_RLC)
Masterlist_Combined_v8 <- right_join(Funbel_Masterlist_without_EoO_sub,
                                     Masterlist_without_EoO_sub,
                                     by = "Species")
write.xlsx(Masterlist_Combined_v8,
           "/data/gent/vo/001/gvo00142/vsc46998/Masterlist_Combined_v8.xlsx", rowNames = FALSE)
