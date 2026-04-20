library(shiny)
library(leaflet)
library(dplyr)
library(ggplot2)
library(readxl)
library(ggspatial)
library(shinyWidgets)
library(sf)
library(DT)
library(lubridate)
library(stringr)

# =========================
# Helpers
# =========================

parse_num <- function(x) {
  x <- as.character(x)
  x <- trimws(x)
  x <- gsub(",", ".", x, fixed = TRUE)
  x <- gsub("[^0-9\\.-]", "", x)
  suppressWarnings(as.numeric(x))
}

safe_text <- function(x) {
  x <- as.character(x)
  x[is.na(x) | x == ""] <- ""
  x
}

make_points_sf <- function(df) {
  df %>%
    filter(!is.na(lat_gps), !is.na(long_gps)) %>%
    st_as_sf(coords = c("long_gps", "lat_gps"), crs = 4326, remove = FALSE)
}




compute_eoo_km2 <- function(pts_sf) {
  if (nrow(pts_sf) < 3) return(NA_real_)
  pts_proj <- st_transform(pts_sf, 3035)
  hull <- st_convex_hull(st_union(pts_proj))
  as.numeric(st_area(hull)) / 1e6
}

compute_aoo_cells <- function(pts_sf, cell_size_m = 2000) {
  if (nrow(pts_sf) == 0) return(0)
  
  pts_proj <- st_transform(pts_sf, 3035)
  xy <- st_coordinates(pts_proj)
  
  cell_id <- paste(
    floor(xy[, 1] / cell_size_m),
    floor(xy[, 2] / cell_size_m),
    sep = "_"
  )
  
  length(unique(cell_id))
}

rate_eoo <- function(eoo_km2) {
  if (is.na(eoo_km2)) return("cannot be calculated")
  if (eoo_km2 < 100) {
    "CR"
  } else if (eoo_km2 < 5000) {
    "EN"
  } else if (eoo_km2 < 20000) {
    "VU"
  } else if (eoo_km2 < 40000) {
    "NT"
  } else {
    "LC"
  }
}

rate_d1 <- function(jed) {
  if (is.na(jed)) return(NA_character_)
  if (jed < 50) {
    "CR"
  } else if (jed < 250) {
    "EN"
  } else if (jed < 1000) {
    "VU"
  } else if (jed < 2000) {
    "NT"
  } else {
    "LC"
  }
}

rate_c1 <- function(jed) {
  if (is.na(jed)) return(NA_character_)
  if (jed < 250) {
    "CR"
  } else if (jed < 2500) {
    "EN"
  } else if (jed < 10000) {
    "VU"
  } else if (jed < 20000) {
    "NT"
  } else {
    "LC"
  }
}



rate_b2 <- function(aoo_km2, locations) {
  if (is.na(aoo_km2)) return(NA_character_)
  if (aoo_km2 < 10 && locations == 1) {
    "CR"
  } else if (aoo_km2 < 500 && locations <= 5) {
    "EN"
  } else if (aoo_km2 < 2000 && locations <= 10) {
    "VU"
  } else if (aoo_km2 < 4000 && locations <= 20) {
    "NT"
  } else {
    "LC"
  }
}

compute_metrics <- function(df_all, fN, individuals_per_site, locality_shift) {
  pts_sf <- make_points_sf(df_all)
  
  aoo_cells <- compute_aoo_cells(pts_sf, cell_size_m = 2000)
  eoo_km2 <- compute_eoo_km2(pts_sf)
  
  aoo_cells_adj <- max(0, aoo_cells + locality_shift)
  aoo_cells_adj <- aoo_cells_adj * (1 + fN / 100)
  
  list(
    aoo_cells = aoo_cells_adj,
    aoo_km2 = aoo_cells_adj * 4,
    eoo_km2 = eoo_km2,
    individuals_total = aoo_cells_adj * individuals_per_site,
    n_records = nrow(df_all),
    missing_coords = sum(df_all$GPS_source == "missing", na.rm = TRUE)
  )
}





year_breaks <- function(years, max_breaks = 10) {
  yrs <- sort(unique(years[!is.na(years)]))
  if (length(yrs) == 0) return(NULL)
  if (length(yrs) <= max_breaks) return(yrs)
  
  brks <- pretty(range(yrs), n = max_breaks)
  brks <- unique(round(brks))
  brks[brks >= min(yrs) & brks <= max(yrs)]
}

build_grid_map <- function(df, quadrants, mzchu) {
  
  # all point coordinates used in the map
  pts_df <- bind_rows(
    df %>%
      filter(!is.na(long_gps), !is.na(lat_gps)) %>%
      transmute(x = long_gps, y = lat_gps),
    
    
    df %>%
      filter(!is.na(extinct), extinct != "", !is.na(lat_gps), !is.na(long_gps)) %>%
      transmute(x = long_gps, y = lat_gps)
  ) %>%
    distinct()
  
  # convex hull polygon
  hull <- NULL
  if (nrow(pts_df) >= 3) {
    pts_sf <- st_as_sf(pts_df, coords = c("x", "y"), crs = 4326)
    hull <- pts_sf %>%
      st_union() %>%
      st_convex_hull() %>%
      st_as_sf()
  }
  
  ggplot() +
    geom_sf(data = quadrants, fill = NA, color = "grey70", linewidth = 0.25) +
    geom_sf(data = mzchu, fill = NA, color = "darkgreen", linewidth = 0.3) +
    geom_sf(data = vzchu, fill = NA, color = "darkgreen", linewidth = 0.3) +
    
    geom_sf(data = borders, fill = NA, color = "grey30", linewidth = 0.3) +
    
    # convex hull
    {if (!is.null(hull)) geom_sf(data = hull, fill = "#effaf0", color = "#9acd9f", alpha = 0.15, linewidth = 0.8)} +
    
    annotation_scale(
      location = "bl",
      pad_x = unit(0.3, "in"),
      pad_y = unit(0.3, "in"),
      width_hint = 0.22
    ) +
    geom_point(
      data = df %>% filter(!is.na(long_gps), !is.na(lat_gps)),
      aes(x = long_gps, y = lat_gps),
      color = "#F28E2B",
      size = 3.2,
      alpha = 0.8
    ) +
    geom_point(
      data = df %>% filter(GPS_source == "reserve centroid"),
      aes(x = long_gps, y = lat_gps),
      color = "#3B6FB6",
      size = 3.2,
      alpha = 0.8
    ) +
    geom_point(
      data = df %>% filter(!is.na(extinct), extinct != "", !is.na(lat_gps), !is.na(long_gps)),
      aes(x = long_gps, y = lat_gps),
      color = "black",
      size = 3.2,
      alpha = 0.5
    ) +
    coord_sf() +
    labs(
      caption = paste0(
        "<span style='color:#F28E2B;'>&#9679;</span> provided coordinates.&nbsp;&nbsp;",
        "<span style='color:#3B6FB6;'>&#9679;</span> centroid / inferred coordinates.&nbsp;&nbsp;",
        "<span style='color:#000000;'>&#9679;</span> extinct localities."
      )
    ) +
    theme_void()+
    theme(
      plot.caption = ggtext::element_markdown(
        size = 15,
        hjust = 0,
        margin = margin(12, 0, 0, 0)
      )
    )
  
}

metric_card <- function(title, value, subtitle = NULL, bg = "#f5f7fa") {
  tags$div(
    style = paste(
      "background:", bg, ";",
      "border-radius:12px;",
      "padding:14px 16px;",
      "margin-bottom:12px;",
      "box-shadow:0 1px 4px rgba(0,0,0,0.08);"
    ),
    tags$div(style = "font-size:13px;color:#556; margin-bottom:4px;", title),
    tags$div(style = "font-size:28px;font-weight:700;line-height:1.1;", value),
    if (!is.null(subtitle)) tags$div(style = "font-size:12px;color:#667; margin-top:4px;", subtitle)
  )
}

# =========================
# Data
# =========================

data_app <- read_excel("data.xlsx") %>%
  mutate(
    date = dmy(date),
    year = year(date),
    month = month(date),
    lat_gps   = parse_num(lat_gps),
    long_gps  = parse_num(long_gps),
    species   = trimws(as.character(species)),
    genus    = word(species, 1),
    source     = trimws(as.character(source))
  ) %>%
  filter(!is.na(genus), genus != "", !is.na(species), species != "")

mzchu <- read_sf("./GIS_data/shapes/mzchu.shp") %>%
  st_transform(4326)
vzchu <- read_sf("./GIS_data/shapes/vzchu.shp") %>%
  st_transform(4326)
borders <- RCzechia::republika("low")%>%st_transform(borders, 
                                                     crs = 4326)


quadrants <- read_sf("./GIS_data/shapes/kvadr_zakl.shp") %>%
  st_transform(4326)

year_min <- min(data_app$year, na.rm = TRUE)
year_max <- max(data_app$year, na.rm = TRUE)

genus_choices <- sort(unique(data_app$genus))
default_genus <- if ("Amanita" %in% genus_choices) "Amanita" else genus_choices[1]

species_lookup <- data_app %>%
  distinct(genus, species) %>%
  arrange(genus, species) %>%
  group_split(genus) %>%
  setNames(unique(data_app %>% distinct(genus) %>% arrange(genus) %>% pull(genus)))

species_lookup <- lapply(species_lookup, function(x) x$species)

default_settings <- list(
  yearInput = c(year_min, year_max),
  fN = 0,
  individuals = 20,
  locations = 1,
  localities = 0
)

# =========================
# UI
# =========================

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      .download-row .btn { margin-right: 8px; margin-bottom: 8px; }
      .control-row { margin-top: 10px; margin-bottom: 10px; }
    "))
  ),
  
  titlePanel("Red List app"),
  p("Example from Czechia"),
  
  sidebarLayout(
    sidebarPanel(
      width = 2,
      
      selectizeInput(
        "genus",
        "Select genus",
        choices = genus_choices,
        selected = default_genus,
        options = list(placeholder = "Choose genus")
      ),
      
      selectizeInput(
        "species",
        "Select species",
        choices = NULL,
        selected = NULL,
        options = list(placeholder = "Start typing species")
      ),
      
      pickerInput(
        "source",
        "Source",
        choices = character(0),
        selected = character(0),
        multiple = TRUE,
        options = list(
          `actions-box` = TRUE,
          `live-search` = TRUE,
          size = 10
        )
      ),
      
      sliderInput(
        "yearInput",
        "Time range",
        min = year_min,
        max = year_max,
        value = default_settings$yearInput,
        step = 1,
        sep = ""
      ),
      
      numericInput(
        "fN",
        "Estimated number of unknown localities in % (fN)",
        value = default_settings$fN,
        min = 0,
        max = 10000,
        step = 25
      ),
      
      numericInput(
        "individuals",
        "Number of individuals per locality",
        value = default_settings$individuals,
        min = 0,
        max = 100,
        step = 10
      ),
      
      numericInput(
        "locations",
        "Number of locations",
        value = default_settings$locations,
        min = 1,
        step = 1
      ),
      
      numericInput(
        "localities",
        "Localities without coordinates (+x) / extinct localities (-x)",
        value = default_settings$localities,
        min = -100,
        step = 1
      ),
      
      div(
        class = "control-row",
        actionButton("reset_all", "Reset all filters", icon = icon("rotate-left"))
      ),
      
      tags$hr(),
      
      div(
        class = "download-row",
        downloadButton("download_records", "Download filtered records"),
        downloadButton("download_iucn", "Download IUCN summary"), 
        downloadButton("download_script", "Download whole script")
      )
    ),
    
    mainPanel(
      width = 10,
      tabsetPanel(
        tabPanel("Map", leafletOutput("map", height = 700)),
        
        tabPanel("Records", DTOutput("table")),
        
        tabPanel(
          "Analysis",
          
          h4("Headline metrics"),
          uiOutput("metric_cards"),
          br(),
          
          # --- IUCN + Phenology ---
          fluidRow(
            column(
              8,
              div(
                style = "
          background-color: #f7f7f7;
          border-left: 6px solid #c0392b;
          padding: 12px 16px;
          border-radius: 8px;
          margin-bottom: 20px;
          min-height: 320px;
        ",
                h4("IUCN categories"),
                tableOutput("cat"),
                br(),
                htmlOutput("analysis_flags")
              )
            ),
            column(
              4,
              h4("Phenology"),
              plotOutput("hist_m", height = 300)
            )
          ),
          
          # --- Map + time series ---
          fluidRow(
            column(
              8,
              h4("Grid map"),
              plotOutput("map_kv_analysis", height = 500)
            ),
            column(
              4,
              h4("Records through time"),
              plotOutput("hist", height = 300)
            )
          )
        ),
        tabPanel("Read me", 
                 HTML("<h3>Feel free to modify script, reuse it for your national Red List assesment.</h3>"),
                 div(style = "height: 10px;"),
                 HTML("<h5>© Monika Kolényová, 424056@mail.muni.cz</h5>"),
                 div(style = "height: 10px;"),
                 HTML("<h5>Some records are missing coordinates, so the calculation may be incomplete.</h5>"),
                 HTML("<p><b>To correct missing coordinates (AOO, number of individuals, and localities), use the field in the side panel (number of localities without coordinates).</b></p>"),
                 HTML("<p><u>The calculated categories for individual criteria are valid only if additional conditions are also met!</u></p>"),
                 
              #   tableOutput("cat"),
                 div(style = "height: 30px;"),
                 HTML("<h4>Workflow used to produce Czech Red List:</h4>"),
                 
                 
                 div(style = "height: 30px;"),
                 HTML("<p><b>Estimate of the number of unknown localities</b></p>"),
                 div(style = "height: 20px;"),
                 HTML("<p><u>Estimate by what percentage the number of localities would increase if those currently unknown were included.</u></p>"),
                 HTML("<p><u>There are two options here – make an estimate based on your own experience, or use the following procedure.</u></p>"),
                 HTML("<p>1) fN = 100</p>"),
                 HTML("<p>2) if the species is well known AND/OR already included in the Red List, then fN = fN / 2</p>"),
                 HTML("<p>3) if the species is associated with a narrowly defined and rare substrate / habitat, then fN = fN / 2</p>"),
                 HTML("<p>4) if the species is small, inconspicuous, or grows hidden, then fN = fN × 2</p>"),
                 HTML("<p>5) if the species belongs to a taxonomically difficult group (identifiable only by a specialist), then fN = fN × 2</p>"),
                 
                 div(style = "height: 30px;"),
                 HTML("<p><b>Number of individuals per locality:</b></p>"),
                 div(style = "height: 10px;"),
                 HTML("<p><u>ectomycorrhizal fungi</u></p>"),
                 HTML("<p>(5-) 20 (-40) individuals / locality – species forming a mycelial mat (lower fragmentation), i.e. hydnoid fungi, Boletopsis, Gautieria, Gomphus, Hysterangium, and Ramaria</p>"),
                 HTML("<p>(10-) 40 (-80) individuals / locality – other ectomycorrhizal species</p>"),
                 div(style = "height: 10px;"),
                 HTML("<p><u>lignicolous fungi</u></p>"),
                 HTML("<p>(5-) 20 (-40) individuals / locality (~ 10 trunks per locality)</p>"),
                 div(style = "height: 10px;"),
                 HTML("<p><u>terrestrial saprotrophic species</u></p>"),
                 HTML("<p>(10-) 40 (-80) individuals / locality</p>"),
                 div(style = "height: 10px;"),
                 HTML("<p><u>coprophilous and muscicolous species</u></p>"),
                 HTML("<p>40 individuals / locality</p>"),
                 div(style = "height: 10px;"),
                 HTML("<p><u>fungicolous species</u></p>"),
                 HTML("<p>20 individuals / locality</p>"),
                 div(style = "height: 40px;"),
                 
                 HTML("<p><b>Number of locations:</b></p>"),
                 div(style = "height: 20px;"),
                 HTML("<p>If locally acting negative factors predominate (construction, logging, extraction of mineral resources, ...), the number of locations is the same as the number of localities.</p>"),
                 HTML("<p>If broadly acting negative factors predominate (eutrophication due to nitrogen deposition, climate change, bark beetle outbreaks, changes in management, ...), the number of locations corresponds to the number of larger units (regions, mountain ranges, ...). Try to estimate it from the map.</p>"),
                 div(style = "height: 20px;"),
                 
                 div(style = "height: 30px;"),
                 HTML("<p><b>Length of 3 generations:</b></p>"),
                 div(style = "height: 20px;"),
                 HTML("<p>* fungi on ephemeral or short-lived substrates (dung): 10 years.</p>"),
                 HTML("<p>* lignicolous species: 20–50 years depending on wood type.</p>"),
                 HTML("<p>- 50 years: oak, pine (elm?)</p>"),
                 HTML("<p>- 30 years: spruce, beech (fir?, maple?, ash?)</p>"),
                 HTML("<p>- 20 years: birch, alder, aspen (willow?)</p>"),
                 HTML("<p>* ectomycorrhizal fungi: 50 years.</p>"),
                 HTML("<p>* saprotrophic fungi in soil and litter: 20–50 years.</p>"),
                 
                 div(style = "height: 30px;"),
                 HTML("<p><b>Criterion A:</b></p>"),
                 div(style = "height: 20px;"),
                 HTML("<p>A1: Population reduction in the past, where the causes of decline are clearly reversible AND known AND have ceased</p>"),
                 HTML("<p>  decline over three generations for A1 - CR ≥90%, EN ≥70%, VU ≥50%</p>"),
                 HTML("<p>A2: Population reduction in the past, where the causes of decline may not have ceased OR may not be understood OR may not be reversible</p>"),
                 HTML("<p>A3: Population reduction projected or suspected in the future (up to a maximum of 100 years)</p>"),
                 HTML("<p>A4: Population reduction (up to a maximum of 100 years), where the time period includes both past and future, and where the causes of decline may not have ceased OR may not be understood OR may not be reversible</p>"),
                 HTML("<p>  decline over three generations for A2/A3/A4 - CR ≥80%, EN ≥50%, VU ≥30%</p>"),
                 HTML("<p><i><u>Use (declining host trees, close association required)</u></i></p>"),
                 HTML("<p><i> - fir: VU A2 for ECM, EN A3 for lignicolous species on trunks</i></p>"),
                 HTML("<p><i> - elm: NT A2 for ECM, EN A4 for lignicolous species on trunks</i></p>"),
                 HTML("<p><i> - juniper: VU A2 for lignicolous species</i></p>"),
                 HTML("<p><i><u>Use (declining habitats, close association required)</u></i></p>"),
                 HTML("<p><i> - calcareous fens (R2.1): CR A2</i></p>"),
                 HTML("<p><i> - non-calcareous moss-rich fens (R2.2): CR A2</i></p>"),
                 HTML("<p><i> - transition mires (R2.3): VU A2</i></p>"),
                 HTML("<p><i> - open raised bogs (R3.1): VU A2</i></p>"),
                 HTML("<p><i> - hardwood floodplain forests (L2.3): VU A4</i></p>"),
                 HTML("<p><i> - softwood floodplain forests (L2.4): EN A4</i></p>"),
                 HTML("<p><i> - Central European basiphilous thermophilous oak forests (L6.4): VU A4</i></p>"),
                 HTML("<p><i> - wet acidophilous oak forests: VU A4</i></p>"),
                 HTML("<p><i> - forest-steppe pine forests (L8.2): VU A4</i></p>"),
                 HTML("<p><i> - ECM species of species-rich oligotrophic pine and spruce forests: VU A4</i></p>"), 
                 
                 div(style = "height: 40px;"),
                 HTML("<p><b>Criterion B1:</b></p>"),
                 div(style = "height: 20px;"),
                 HTML("<p>Must meet a small extent of occurrence (EOO, see results), continuing decline in habitat area, extent, or quality, and one of the following:</p>"),
                 HTML("<p>- CR: 1 location or severely fragmented occurrence</p>"),
                 HTML("<p>- EN: ≤5 locations or severely fragmented occurrence</p>"),
                 HTML("<p>- VU: ≤10 locations or severely fragmented occurrence</p>"),
                 HTML("<p>Note – the true EOO may differ greatly if there is an outlying locality without coordinates!</p>"),
                 
                 div(style = "height: 30px;"),
                 HTML("<p><b>Criterion B2:</b></p>"),
                 div(style = "height: 20px;"),
                 HTML("<p>Must meet a small area of occupancy (AOO, see results), continuing decline in habitat area, extent, or quality, and one of the following:</p>"),
                 HTML("<p>- CR: 1 location or severely fragmented occurrence</p>"),
                 HTML("<p>- EN: ≤5 locations or severely fragmented occurrence</p>"),
                 HTML("<p>- VU: ≤10 locations or severely fragmented occurrence</p>"),
                 
                 div(style = "height: 40px;"),
                 HTML("<p><b>Criterion C1:</b></p>"),
                 div(style = "height: 20px;"),
                 HTML("<p>Must meet the number of individuals (see results) and at the same time a quantified continuing decline (in the past, present, or future):</p>"),
                 HTML("<p>- CR: 25% over 1 generation (57.8% over 3 generations) and <250 individuals</p>"),
                 HTML("<p>- EN: 20% over 2 generations (28.4% over 3 generations) and <2500 individuals</p>"),
                 HTML("<p>- VU: 10% over 3 generations and <10000 individuals</p>"),
                 
                 
                 div(style = "height: 30px;"),
                 HTML("<p><b>Criterion C2:</b></p>"),
                 div(style = "height: 20px;"),
                 HTML("<p>Must meet the maximum number of individuals in each subpopulation (see results and check against the map) and at the same time a continuing decline (in the past, present, or future):</p>"),
                 HTML("<p>- CR: ≤50 individuals in each subpopulation</p>"),
                 HTML("<p>- EN: ≤250 individuals in each subpopulation</p>"),
                 HTML("<p>- VU: ≤1000 individuals in each subpopulation</p>"),
                 
                 div(style = "height: 30px;"),
                 HTML("<p><b>Criterion D1:</b></p>"),
                 div(style = "height: 20px;"),
                 HTML("<p>Must meet the number of individuals (see results). The species is threatened purely because of rarity.</p>"),
                 HTML("<p>- CR: ≤50 individuals</p>"),
                 HTML("<p>- EN: ≤250 individuals</p>"),
                 HTML("<p>- VU: ≤1000 individuals</p>"),
                 
              
        )
        )
      
    )
  )
)

# =========================
# Server
# =========================

server <- function(input, output, session) {
  
  last_species <- reactiveVal(NULL)
  
  observeEvent(input$genus, {
    req(input$genus)
    
    sp <- species_lookup[[input$genus]]
    if (is.null(sp)) sp <- character(0)
    
    selected_sp <- if (length(sp) > 0) sp[1] else character(0)
    
    freezeReactiveValue(input, "species")
    updateSelectizeInput(
      session,
      "species",
      choices = sp,
      selected = selected_sp,
      server = TRUE
    )
  }, ignoreInit = FALSE)
  
  observeEvent(input$species, {
    req(input$genus, input$species)
    
    if (identical(last_species(), input$species)) {
      return()
    }
    last_species(input$species)
    
    freezeReactiveValue(input, "yearInput")
    freezeReactiveValue(input, "fN")
    freezeReactiveValue(input, "individuals")
    freezeReactiveValue(input, "locations")
    freezeReactiveValue(input, "localities")
    freezeReactiveValue(input, "source")
    
    updateSliderInput(session, "yearInput", value = default_settings$yearInput)
    updateNumericInput(session, "fN", value = default_settings$fN)
    updateNumericInput(session, "individuals", value = default_settings$individuals)
    updateNumericInput(session, "locations", value = default_settings$locations)
    updateNumericInput(session, "localities", value = default_settings$localities)
    
    src_reset_tbl <- data_app %>%
      filter(
        genus == input$genus,
        species == input$species,
        between(year, default_settings$yearInput[1], default_settings$yearInput[2])
      ) %>%
      count(source, name = "n") %>%
      arrange(source)
    
    src_choices <- setNames(
      src_reset_tbl$source,
      paste0(src_reset_tbl$source, " (", src_reset_tbl$n, ")")
    )
    
    updatePickerInput(
      session,
      "source",
      choices = src_choices,
      selected = src_reset_tbl$source
    )
  }, ignoreInit = TRUE)
  
  observeEvent(input$reset_all, {
    freezeReactiveValue(input, "genus")
    freezeReactiveValue(input, "species")
    freezeReactiveValue(input, "yearInput")
    freezeReactiveValue(input, "fN")
    freezeReactiveValue(input, "individuals")
    freezeReactiveValue(input, "locations")
    freezeReactiveValue(input, "localities")
    freezeReactiveValue(input, "source")
    
    updateSelectizeInput(session, "genus", selected = default_genus)
    updateSliderInput(session, "yearInput", value = default_settings$yearInput)
    updateNumericInput(session, "fN", value = default_settings$fN)
    updateNumericInput(session, "individuals", value = default_settings$individuals)
    updateNumericInput(session, "locations", value = default_settings$locations)
    updateNumericInput(session, "localities", value = default_settings$localities)
  })
  
  source_choices_tbl <- reactive({
    req(input$genus, input$species)
    
    data_app %>%
      filter(
        genus == input$genus,
        species == input$species,
        between(year, input$yearInput[1], input$yearInput[2])
      ) %>%
      count(source, name = "n") %>%
      arrange(source)
  }) %>% bindCache(input$genus, input$species, input$yearInput)
  
  observeEvent(list(input$species, input$yearInput), {
    req(input$species)
    
    src_tbl <- source_choices_tbl()
    selected_src <- intersect(isolate(input$source), src_tbl$source)
    if (!length(selected_src)) selected_src <- src_tbl$source
    
    src_choices <- setNames(
      src_tbl$source,
      paste0(src_tbl$source, " (", src_tbl$n, ")")
    )
    
    freezeReactiveValue(input, "source")
    updatePickerInput(
      session,
      "source",
      choices = src_choices,
      selected = selected_src
    )
  }, ignoreInit = FALSE)
  
  filteredData <- reactive({
    req(input$genus, input$species)
    
    df <- data_app %>%
      filter(
        genus == input$genus,
        species == input$species,
        between(year, input$yearInput[1], input$yearInput[2])
      )
    
    if (!is.null(input$source) && length(input$source) > 0) {
      df <- df %>% filter(source %in% input$source)
    } else {
      df <- df[0, ]
    }
    
    validate(need(nrow(df) > 0, "No data for the current filter."))
    df
  }) %>% bindCache(input$genus, input$species, input$yearInput, input$source)
  
  filteredDataGPS <- reactive({
    filteredData() %>%
      filter(!is.na(lat_gps), !is.na(long_gps))
  }) %>% bindCache(input$genus, input$species, input$yearInput, input$source)
  
  metrics <- reactive({
    compute_metrics(
      df_all = filteredData(),
      fN = input$fN,
      individuals_per_site = input$individuals,
      locality_shift = input$localities
    )
  }) %>% bindCache(
    input$genus, input$species, input$yearInput, input$source,
    input$fN, input$individuals, input$localities
  )
  
  metrics_table_df <- reactive({
    m <- metrics()
    
    data.frame(
      Metric = c(
        "AOO (km2)",
        "EOO (km2)",
        "Number of localities",
        "Number of individuals",
        "Number of records",
        "Records without coordinates"
      ),
      Value = c(
        round(m$aoo_km2, 0),
        ifelse(is.na(m$eoo_km2), "cannot be calculated", round(m$eoo_km2, 0)),
        round(m$aoo_cells, 0),
        round(m$individuals_total, 0),
        round(m$n_records, 0),
        round(m$missing_coords, 0)
      ),
      check.names = FALSE
    )
  }) %>% bindCache(
    input$genus, input$species, input$yearInput, input$source,
    input$fN, input$individuals, input$localities
  )
  
  categories_df <- reactive({
    m <- metrics()
    
    data.frame(
      Criterion = c("B1", "B2", "C1", "C2", "D1"),
      Category = c(
        rate_eoo(m$eoo_km2),
        rate_b2(m$aoo_km2, input$locations),
        rate_c1(m$individuals_total),
        "",
        rate_d1(m$individuals_total)
      ),
      Conditions = c(
        "continuing decline and fragmented range / completed locations",
        "continuing decline and fragmented range / completed locations",
        "continuing quantified decline",
        "continuing decline and small local populations / all in one local population",
        "none"
      ),
      Thresholds = c(
        "",
        "",
        "",
        paste0(
          "CR ≤ ", round(50 / input$individuals, 0),
          "; EN ≤ ", round(250 / input$individuals, 0),
          "; VU ≤ ", round(1000 / input$individuals, 0)
        ),
        ""
      ),
      check.names = FALSE
    )
  }) %>% bindCache(
    input$genus, input$species, input$yearInput, input$source,
    input$fN, input$individuals, input$localities, input$locations
  )
  
  output$metric_cards <- renderUI({
    m <- metrics()
    
    val_or_na <- function(x, digits = 0) {
      if (is.null(x) || is.na(x)) "NA" else round(x, digits)
    }
    
    tagList(
      fluidRow(
        column(4, metric_card("AOO", val_or_na(m$aoo_km2), "km²", "#a1d7d7")),
        column(4, metric_card("EOO", val_or_na(m$eoo_km2), "km²", "#effaf0")),
        column(4, metric_card("Localities", val_or_na(m$aoo_cells), NULL, "#f5ee9e"))
      ),
      fluidRow(
        column(4, metric_card("Individuals", val_or_na(m$individuals_total), NULL, "#e2eeee")),
        column(4, metric_card("Records", val_or_na(m$n_records), NULL, "#f7eeee")),
        column(4, metric_card("Coordinate missing", val_or_na(m$missing_coords), NULL, "#fff7e8"))
      )
    )
  })
  
  output$analysis_flags <- renderUI({
    m <- metrics()
    notes <- character(0)
    
    if (is.na(m$eoo_km2)) {
      notes <- c(notes, "EOO cannot be calculated because fewer than 3 records with GPS coordinates are available.")
    }
    if (m$missing_coords > 0) {
      notes <- c(notes, paste0("There are ", m$missing_coords, " filtered records without coordinates."))
    }
    if (nrow(filteredDataGPS()) < 3) {
      notes <- c(notes, "Very few georeferenced records are available for spatial assessment.")
    }
    
    if (length(notes) == 0) {
      HTML("<div style='color:#355e3b;'><b>Data quality check:</b> no immediate warning flags.</div>")
    } else {
      HTML(paste0(
        "<div style='color:#7a3b00;'><b>Data quality flags:</b><ul><li>",
        paste(notes, collapse = "</li><li>"),
        "</li></ul></div>"
      ))
    }
  })
  output$map <- renderLeaflet({
    
    # make plain label table for quadrant numbers
    quad_pts <- sf::st_point_on_surface(sf::st_transform(quadrants, 4326))
    quad_xy  <- sf::st_coordinates(quad_pts)
    
    quad_labels <- data.frame(
      lng = quad_xy[, 1],
      lat = quad_xy[, 2],
      lab = as.character(quad_pts$Kvadr_zakl)
    )
    
    leaflet(options = leafletOptions(zoomControl = TRUE)) %>% 
      addProviderTiles(providers$CartoDB.Positron, group = "Light map") %>% 
      addProviderTiles(providers$OpenTopoMap, group = "Topographic map") %>% 
      
      addPolygons(
        data = quadrants,
        color = "#7f7f7f",
        weight = 0.6,
        fill = FALSE,
        group = "Grid"
      ) %>% 
      
      addLabelOnlyMarkers(
        data = quad_labels,
        lng = ~lng,
        lat = ~lat,
        label = ~lab,
        group = "Grid",
        labelOptions = labelOptions(
          noHide = TRUE,
          direction = "center",
          textOnly = TRUE,
          style = list(
            "font-size" = "9px",
            "font-weight" = "bold",
            "color" = "#555555"
          )
        )
      ) %>% 
      
      addPolygons(
        data = mzchu,
        color = "#1b7837",
        weight = 1,
        fill = FALSE,
        group = "Protected areas"
      ) %>% 
      
      addScaleBar(position = "bottomleft") %>% 
      addLayersControl(
        baseGroups = c("Light map", "Topographic map"),
        overlayGroups = c("Grid", "Protected areas", "Records"),
        options = layersControlOptions(collapsed = FALSE)
      ) %>% 
      hideGroup("Grid") %>% 
      setView(lng = 15.5, lat = 49.8, zoom = 7) 
  })
  
  observeEvent(filteredDataGPS(), {
    df <- tryCatch(filteredDataGPS(), error = function(e) NULL)
    
    proxy <- leafletProxy("map")
    proxy %>% clearGroup("Records")
    
    if (is.null(df) || nrow(df) == 0) {
      return()
    }
    
    popup_txt <- paste0(
      "<b>Locality:</b> ", safe_text(df$locality), "<br>",
      "<b>Year:</b> ", safe_text(df$year), "<br>",
      "<b>Collector:</b> ", safe_text(df$leg), "<br>",
      "<b>Habitat:</b> ", safe_text(df$biotope), "<br>",
      "<b>Source:</b> ", safe_text(df$source), "<br>",
      "<b>Note:</b> ", substr(safe_text(df$note), 1, 400), "<br>"
      
    )
    
    proxy %>%
      addCircleMarkers(
        data = df,
        lng = ~long_gps,
        lat = ~lat_gps,
        radius = 5,
        stroke = FALSE,
        fillOpacity = 0.75,
        color = "#d7301f",
        popup = popup_txt,
        group = "Records"
      )
    
    if (nrow(df) == 1) {
      proxy %>% setView(lng = df$long_gps[1], lat = df$lat_gps[1], zoom = 8)
    } else {
      pts_sf <- make_points_sf(df)
      bb <- st_bbox(pts_sf)
      proxy %>% fitBounds(bb["xmin"], bb["ymin"], bb["xmax"], bb["ymax"])
    }
  }, ignoreInit = FALSE)
  
  output$table <- renderDT({
    df <- filteredData()
    # add/remove any aditional columns
    out <- data.frame(
      
      Locality = df$locality,
      Identification = df$tax_note,
      Biotope = df$biotope,
      Substrate = df$substrate,
      Date = df$date,
      Collector_Determiner = paste(df$leg, "/", df$det),
      Source = df$source,
      Coordinate_source = df$GPS_source,
      Extinct_locality = as.character(df$extinct),
      Note = df$note,
      check.names = FALSE
    )
    
    datatable(
      out,
      rownames = FALSE,
      filter = "top",
      options = list(
        pageLength = 25,
        scrollX = TRUE
      )
    )
  }) 
  output$metrics_table <- renderTable({
    metrics_table_df()
  })
  
  output$cat <- renderTable({
    categories_df()
  })
  
  
  output$map_kv_analysis <- renderPlot({
    df <- filteredData()
    build_grid_map(df, quadrants, mzchu)
  }) %>% bindCache(input$genus, input$species, input$yearInput, input$source)
  
  output$hist <- renderPlot({
    df <- filteredData() %>%
      filter(!is.na(year))
    
    validate(need(nrow(df) > 0, "Year is missing for the current filter."))
    
    df_year <- df %>%
      count(year, GPS_source, name = "n")
    
    brks <- year_breaks(df_year$year)
   
    
    ggplot(df_year, aes(x = year, y = n, fill = GPS_source)) +
      geom_col(width = 0.9) +
      scale_x_continuous(
        breaks = brks,
        labels = scales::label_number(big.mark = "", accuracy = 1)
      ) +
      labs(x = "Year", y = "Number of records", fill = "Coordinates") +
      theme_minimal() +

      theme(
        legend.position = "bottom",
        legend.direction = "horizontal",
        axis.text.x = element_text(size = 14, face = "bold"),
        axis.text.y = element_text(size = 14, face = "bold"),
        legend.box = "horizontal"
      ) +
      guides(fill = guide_legend(nrow = 1))
  }) %>% bindCache(input$genus, input$species, input$yearInput, input$source)
  
  output$hist_m <- renderPlot({
    df <- filteredData() %>%
      filter(!is.na(month))
    
    validate(need(nrow(df) > 0, "Month of record is missing for the current filter."))
    
    month_df <- df %>%
      count(month, name = "n") %>%
      tidyr::complete(month = 1:12, fill = list(n = 0)) %>%
      arrange(month) %>%
      mutate(
        month_lab = factor(month, levels = 1:12, labels = month.abb)
      )
    
    month_cols <- c(
      "Jan" = "#3B6FB6",
      "Feb" = "#8FBCE6",
      "Mar" = "#4CAF50",
      "Apr" = "#7BC87C",
      "May" = "#F4A6C1",
      "Jun" = "#d4f65a",
      "Jul" = "#F6E75A",
      "Aug" = "#F6C85F",
      "Sep" = "#F28E2B",
      "Oct" = "#C97B36",
      "Nov" = "#8C564B",
      "Dec" = "#2C5AA0"
    )
    
    ggplot(month_df, aes(x = month_lab, y = n, fill = month_lab)) +
      geom_col(width = 1, color = "white") +
      coord_polar() +
      scale_fill_manual(values = month_cols) +
      labs(x = NULL, y = NULL) +
      theme_minimal() +
      theme(
        axis.text.y = element_blank(),
        axis.text.x = element_text(size = 14, face = "bold"),
        axis.title = element_blank(),
        panel.grid = element_blank(),
        legend.position = "none"
      )
  }) %>% bindCache(input$genus, input$species, input$yearInput, input$source)
  
  output$download_records <- downloadHandler(
    filename = function() {
      paste0(
        gsub("[^A-Za-z0-9_\\-]+", "_", input$genus), "_",
        gsub("[^A-Za-z0-9_\\-]+", "_", input$species), "_records.csv"
      )
    },
    content = function(file) {
      df <- filteredData()
      write.csv(df, file, row.names = FALSE, na = "")
    }
  )
  
  output$download_iucn <- downloadHandler(
    filename = function() {
      paste0(
        gsub("[^A-Za-z0-9_\\-]+", "_", input$genus), "_",
        gsub("[^A-Za-z0-9_\\-]+", "_", input$species), "_iucn_summary.csv"
      )
    },
    content = function(file) {
      a <- metrics_table_df()
      b <- categories_df()
      sep_row <- data.frame(Metric = "", Value = "", check.names = FALSE)
      
      names(b) <- c("Metric", "Value", "Condition", "Threshold")
      out <- rbind(
        a,
        sep_row,
        data.frame(Metric = "Criterion", Value = "Category", check.names = FALSE),
        data.frame(Metric = b$Metric, Value = b$Value, check.names = FALSE)
      )
      
      write.csv(out, file, row.names = FALSE, na = "")
    }
  )
  output$download_script <- downloadHandler(
    filename = function() {
      "app.R"
    },
    content = function(file) {
      file.copy("app.R", file)
    }
  )
}

shinyApp(ui, server)
