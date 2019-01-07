# Title: Gen Info New Build Map
# Author: Stephan Jacobs
# Date: 24 September 2018
# Description: Pulls in one edition of AEMO's Gen Info spreadsheets and plots new builds on a map
  
#  Summon Libraries -------------------------------------------------------
library(openxlsx)
library(magrittr)
library(plyr)
library(dplyr)
library(rvest)
library(maps)
library(ggmap)
library(maptools)
library(plotly)


# Pull in local function and create data directory ------------------------

x <- list.files(path = "./R", full.names = T)
invisible(lapply(x, source))
rm(x)

dir.create("./data")


# Download the latest Gen Info Files --------------------------------------
dataURL <- "https://www.aemo.com.au/Electricity/National-Electricity-Market-NEM/Planning-and-forecasting/Generation-information"
baseURL <- "https://www.aemo.com.au"

# Get table HTML
GenInfoTable <- dataURL %>%
  read_html() %>%
  html_nodes(xpath = "//table")

# Get Table text
GenInfoTableDF <- GenInfoTable %>% html_table(header = TRUE) %>% extract2(1)
colnames(GenInfoTableDF)[2:6] <- rep("state", 5) 

# Get links to spreadsheets
DateCol <- GenInfoTable %>% html_nodes(xpath = "//tr/td[1]") %>% html_text()
NSW <- GenInfoTable %>%  html_nodes(xpath = "//tr/td[2]/a[@href]") %>% html_attr("href")
QLD <- GenInfoTable %>%  html_nodes(xpath = "//tr/td[3]/a[@href]") %>% html_attr("href")
SA  <- GenInfoTable %>%  html_nodes(xpath = "//tr/td[4]/a[@href]") %>% html_attr("href")
TAS <- GenInfoTable %>%  html_nodes(xpath = "//tr/td[5]/a[@href]") %>% html_attr("href")
VIC  <- GenInfoTable %>%  html_nodes(xpath = "//tr/td[6]/a[@href]") %>% html_attr("href")

links <- data.frame(Date = DateCol[2:20], NSW = NSW, QLD = QLD, SA = SA, TAS = TAS, VIC = VIC, stringsAsFactors = F)

# Pick edition of Gen Info

edition <- 2 # TODO: make this more intuitive for the user
for (state in 2:6) {
  filename <- paste0("./data/GenInfo_", gsub(pattern = "[^0-z.]+", replacement = "_", links[edition, 1]), "_", GenInfoTableDF[edition, state], ".xlsx")
  download.file(url = paste0(baseURL, links[edition, state]), destfile = filename, quiet = T)
}



# Pull In Spreadsheets ----------------------------------------------------

fileNames <- list.files(path = "./data/", pattern = ".xlsx", full.names = T)

NewDev <- ldply(fileNames, GetNewDevelopments)



# Get Locations for map ---------------------------------------------------
# There are no official Lat Long coordinates as part of Gen Info, so 
# this code parses the name and take a guess that the name is also more or 
# less the location.

locationNames <- NewDev %>% 
  rowwise() %>% 
  mutate(Spaces     = gregexpr(pattern = " ", Project),
         OneWord    = substr(Project, 1, Spaces[1]),
         TwoWords   = substr(Project, 1, Spaces[2]), 
         SearchTerm = paste(OneWord, ",", region, "Australia"))

# Ask "data science toolkit" for an approximate location.
# This one takes a while to run, go make a cup of tea
LocationOne <-  geocode(location = locationNames$SearchTerm, source = "dsk")
      
GenForChart <- cbind(NewDev, LocationOne)


# Make Plotly Chart -------------------------------------------------------
mp <- NULL
mapWorld <- borders(database = "world", regions = "Australia" , colour="gray50", fill="gray50") # create a layer of borders
mp <- ggplot() +   mapWorld

mp <- mp + geom_jitter(aes(x = GenForChart$lon, y = GenForChart$lat, colour = GenForChart$summary_bucket))
ggplotly(mp)

