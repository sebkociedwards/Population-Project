cat("R shiny pipeline started\n")
library(shiny)
library(bs4Dash)
library(data.table)
library(shinyWidgets)
library(RColorBrewer)

# Read data
start_time <- Sys.time()
data_dir <- Sys.getenv("SHINY_DATA_DIR")
life_table <- fread(file.path(data_dir, "life_table.csv"))
country_table <- fread(file.path(data_dir, "country_table.csv"))
income <- fread(file.path(data_dir, "income_status.csv"))

# Set keys for efficient filtering
setkey(life_table, ISO3, Year, Age)
setkey(country_table, ISO3, Year)
setkey(income, ISO3)

end_time <- Sys.time()
cat(sprintf("Data loading took: %.2f seconds\n", as.numeric(difftime(end_time, start_time, units = "secs"))))

# Cache unique values for efficiency
countries <- sort(unique(life_table$ISO3))
years <- sort(unique(life_table$Year))
life_countries <- unique(life_table$ISO3)
country_countries <- unique(country_table$ISO3)
income_by_status <- split(income$ISO3, income$IS)

# Define variable sources and display names
var_sources <- list(
    Age = "life_table",
    Year = "both",
    lx = "life_table",
    mx = "life_table",
    qx = "life_table",
    ex = "life_table",
    T = "country_table",
    N_ratio = "country_table",
    H_N = "country_table",
    mx_norm_ratio = "country_table",
    mx_skew = "country_table",
    mx_kurtosis = "country_table",
    B = "country_table",                    # ← ADD
    M = "country_table",                    # ← ADD
    Z = "country_table",                    # ← ADD
    PrR = "country_table",                  # ← ADD
    prop_survive_to_M = "country_table"     # ← ADD
)


var_display_names <- c(
    "Age" = "Age",
    "Year" = "Year",
    "lx" = "Survivorship (lx)",
    "mx" = "Fertility (mx)",
    "qx" = "Death Probability (qx)",
    "ex" = "Life Expectancy (ex)",
    "T" = "Generation Time (T)",
    "N_ratio" = "Ne/N Ratio",
    "H_N" = "H_N",
    "mx_norm_ratio" = "R0/TFR",
    "mx_skew" = "mx Skew",
    "mx_kurtosis" = "mx Kurtosis",
    "B" = "Fertility Start (B)",                        # ← ADD
    "M" = "Fertility End (M)",                          # ← ADD
    "Z" = "Cohort Longevity (Z)",                       # ← ADD
    "PrR" = "Post-fertile Ratio (PrR)",                 # ← ADD
    "prop_survive_to_M" = "Survival to M"               # ← ADD
)

# Define UI
ui <- dashboardPage(
  dashboardHeader(
    title = dashboardBrand(
      title = "Population Genetics V2.0",
      color = "primary"
    )
  ),
  
  dashboardSidebar(
    sidebarMenu(
      id = "tabs",
      menuItem("Home", tabName = "home", icon = icon("home")),
      menuItem("Analyses", icon = icon("chart-line"), startExpanded = TRUE,
        menuSubItem("Analysis 1", tabName = "analysis_1"),
        menuSubItem("Analysis 2", tabName = "analysis_2"),
        menuSubItem("Analysis 3", tabName = "analysis_3")
      ),
      menuItem("About", tabName = "about", icon = icon("info-circle"))
    ),
    hr(),
    actionButton("add_analysis", "Add New Analysis", icon = icon("plus"), 
                 class = "btn-success", style = "width: 90%; margin: 5%;")
  ),
  
  dashboardBody(
    tags$head(
      tags$style(HTML("
        .content-wrapper, .main-footer, .main-header, .main-sidebar {
          font-family: 'Helvetica Neue', Arial, sans-serif;
        }
        .box-header {
          font-weight: 600;
        }
        .selectize-control {
          font-size: 14px;
        }
      "))
    ),
    
    tabItems(
      # Home Tab
      tabItem(
        tabName = "home",
        fluidRow(
          bs4Card(
            title = "Welcome to Population Genetics Analysis",
            status = "primary",
            width = 12,
            
            h4("Getting Started"),
            p("This interactive platform allows you to explore demographic transitions through multiple analytical lenses."),
            
            h5("Quick Start:"),
            tags$ol(
              tags$li("Click on 'Analysis 1' to view or customize an analysis"),
              tags$li("Use 'Add New Analysis' to create additional comparisons"),
              tags$li("Download publication-ready plots with the download button")
            ),
            
            h5("Features:"),
            tags$ul(
              tags$li("Multiple simultaneous analyses with independent settings"),
              tags$li("Flexible variable selection (Age, Year, lx, mx, T, N_ratio, and more)"),
              tags$li("Income-based filtering using World Bank classifications"),
              tags$li("Line and scatter plot options"),
              tags$li("Publication-ready downloadable plots")
            )
          )
        )
      ),
      
      # Analysis 1
      tabItem(
        tabName = "analysis_1",
        uiOutput("analysis_ui_1")
      ),
      
      # Analysis 2
      tabItem(
        tabName = "analysis_2",
        uiOutput("analysis_ui_2")
      ),
      
      # Analysis 3
      tabItem(
        tabName = "analysis_3",
        uiOutput("analysis_ui_3")
      ),
      
      # About Tab
      tabItem(
        tabName = "about",
        bs4Card(
          title = "About This Application",
          status = "info",
          width = 12,
          
          h4("Population Genetics: Demographic Transitions Analysis"),
          p("This application analyzes demographic data from the Human Mortality Database (HMD) and Human Fertility Database (HFD) to explore population genetics metrics across industrialization periods."),
          
          h5("Research Focus:"),
          p("Testing whether incidence of disease affects effective population size (Ne) through demographic mediators (survivorship lx and fertility mx); analysed by employing a Bayesian network."),
          
          h5("Data Sources:"),
          tags$ul(
            tags$li("Human Mortality Database (HMD) - life tables across 30 countries, 1800-present"),
            tags$li("Human Fertility Database (HFD) - age-specific fertility rates"),
            tags$li("World Bank - income classifications by country and year")
          ),
          
          h5("Author:"),
          p("Joshua - PhD Student in Population Genetics"),
          
          h5("Version:"),
          p("2.0 - ", format(Sys.Date(), "%B %Y"))
        )
      )
    )
  )
)

# Server logic
server <- function(input, output, session) {
  
  # Track active analyses
  active_analyses <- reactiveVal(c(1, 2, 3))
  max_analysis_id <- reactiveVal(3)
  
  # Add new analysis
  observeEvent(input$add_analysis, {
    current_max <- max_analysis_id()
    new_id <- current_max + 1
    max_analysis_id(new_id)
    
    current_active <- active_analyses()
    active_analyses(c(current_active, new_id))
    
    # Add menu item
    insertUI(
      selector = ".sidebar-menu",
      where = "beforeEnd",
      ui = menuSubItem(
        paste("Analysis", new_id),
        tabName = paste0("analysis_", new_id),
        icon = icon("chart-line")
      )
    )
    
    # Add tab
    insertTab(
      inputId = "tabs",
      tabPanel(
        title = paste("Analysis", new_id),
        value = paste0("analysis_", new_id),
        uiOutput(paste0("analysis_ui_", new_id))
      ),
      target = "about",
      position = "before"
    )
    
    # Switch to new tab
    updateTabItems(session, "tabs", paste0("analysis_", new_id))
  })
  
  # Generate UI for each analysis dynamically
  lapply(1:10, function(i) {  # Support up to 10 analyses
    output[[paste0("analysis_ui_", i)]] <- renderUI({
      if (!(i %in% active_analyses())) return(NULL)
      
      fluidRow(
        # Control Panel
        bs4Card(
          title = "Analysis Parameters",
          status = "primary",
          width = 4,
          collapsible = TRUE,
          
          h5("Analysis Name", class = "font-weight-bold"),
          textInput(paste0("tab_name_", i), 
                    label = NULL,
                    placeholder = "Analysis title",
                    value = if(i == 1) "Year vs Survivorship (lx)" else ""),
          helpText("Auto-updates based on variable selection"),
          
          hr(),
          
          h5("Population Selection", class = "font-weight-bold"),
          switchInput(
            paste0("global_countries_", i),
            label = "Include All Countries",
            value = TRUE,
            onLabel = "Yes",
            offLabel = "No",
            onStatus = "primary"
          ),
          
          conditionalPanel(
            condition = paste0("!input.global_countries_", i),
            pickerInput(
              paste0("country_", i),
              label = NULL,
              choices = countries,
              selected = countries[1],
              multiple = TRUE,
              options = pickerOptions(
                actionsBox = TRUE,
                liveSearch = TRUE,
                maxOptions = 10,
                selectedTextFormat = "count > 3",
                countSelectedText = "{0} countries selected"
              )
            )
          ),
          
          hr(),
          
          h5("Income Stratification", class = "font-weight-bold"),
          switchInput(
            paste0("filter_income_", i),
            label = "Filter by Income Status",
            value = FALSE,
            onLabel = "Yes",
            offLabel = "No",
            onStatus = "success"
          ),
          
          conditionalPanel(
            condition = paste0("input.filter_income_", i),
            pickerInput(
              paste0("income_category_", i),
              label = NULL,
              choices = c("All" = "ALL", 
                         "High" = "H", 
                         "Upper Middle" = "UM", 
                         "Lower Middle" = "LM", 
                         "Low" = "L"),
              selected = "ALL",
              multiple = TRUE
            )
          ),
          
          hr(),
          
          h5("Analysis Variables", class = "font-weight-bold"),
          selectInput(
            paste0("x_variable_", i),
            "X-axis (Independent):",
            choices = var_display_names,
            selected = "Year"
          ),
          
          selectInput(
            paste0("y_variable_", i),
            "Y-axis (Dependent):",
            choices = var_display_names[names(var_display_names) != "Year"],
            selected = if(i == 1) "lx" else "T"
          ),
          
          hr(),
          
          h5("Data Range", class = "font-weight-bold"),
          sliderInput(
            paste0("year_range_", i),
            "Year Range:",
            min = min(years),
            max = max(years),
            value = c(min(years), max(years)),
            step = 1,
            sep = ""
          ),
          
          sliderInput(
            paste0("age_range_", i),
            "Age Range:",
            min = 0,
            max = 110,
            value = c(0, 100),
            step = 1
          ),
          
          hr(),
          
          h5("Plot Options", class = "font-weight-bold"),
          radioButtons(
            paste0("plot_type_", i),
            "Plot Type:",
            choices = c("Line Plot" = "line", "Scatter Plot" = "scatter"),
            selected = "line",
            inline = TRUE
          ),
          
          textInput(
            paste0("plot_title_", i),
            "Custom Plot Title:",
            placeholder = "Leave blank for auto-title"
          ),
          
          textInput(
            paste0("x_label_", i),
            "Custom X-axis Label:",
            placeholder = "Leave blank for default"
          ),
          
          textInput(
            paste0("y_label_", i), 
            "Custom Y-axis Label:",
            placeholder = "Leave blank for default"
          )
        ),
        
        # Main Plot Area
        bs4Card(
          title = textOutput(paste0("plot_card_title_", i)),
          status = "primary",
          width = 8,
          maximizable = TRUE,
          footer = downloadButton(paste0("download_plot_", i), "Download Plot", class = "btn-primary"),
          
          plotOutput(paste0("main_plot_", i), height = "600px")
        )
      )
    })
    
    # Dynamic Y-axis choices
    observe({
      req(input[[paste0("x_variable_", i)]])
      
      x_var <- input[[paste0("x_variable_", i)]]
      x_var_code <- names(var_display_names)[var_display_names == x_var]
      
      y_choices <- var_display_names[names(var_display_names) != x_var_code]
      
      # Restriction: Age can only pair with life_table variables
      if (x_var_code == "Age") {
        y_choices <- y_choices[names(y_choices) %in% c("lx", "mx", "qx", "ex")]
      } else if (x_var_code %in% c("T", "N_ratio", "H_N", "mx_norm_ratio", "mx_skew", "mx_kurtosis")) {
        y_choices <- y_choices[names(y_choices) != "Age"]
      }
      # Year has NO restrictions!
    
      updateSelectInput(session, paste0("y_variable_", i), choices = y_choices)
    })
    
    # Auto-update tab name
    observe({
      req(input[[paste0("x_variable_", i)]], input[[paste0("y_variable_", i)]])
      
      x_var <- input[[paste0("x_variable_", i)]]
      y_var <- input[[paste0("y_variable_", i)]]
      tab_name <- input[[paste0("tab_name_", i)]]
      
      if (is.null(tab_name) || tab_name == "" || grepl("vs", tab_name)) {
        auto_name <- paste(x_var, "vs", y_var)
        updateTextInput(session, paste0("tab_name_", i), value = auto_name)
      }
    })
    
    # Card title
    output[[paste0("plot_card_title_", i)]] <- renderText({
      tab_name <- input[[paste0("tab_name_", i)]]
      if (!is.null(tab_name) && tab_name != "") {
        tab_name
      } else {
        paste(input[[paste0("x_variable_", i)]], "vs", input[[paste0("y_variable_", i)]])
      }
    })
    
    # Reactive data filtering
    filtered_data <- reactive({
      req(input[[paste0("x_variable_", i)]], input[[paste0("y_variable_", i)]])
      
      x_var_code <- names(var_display_names)[var_display_names == input[[paste0("x_variable_", i)]]]
      y_var_code <- names(var_display_names)[var_display_names == input[[paste0("y_variable_", i)]]]
      
      cat(sprintf("\n=== ANALYSIS %d FILTERING ===\n", i))
      cat(sprintf("X: %s (%s), Y: %s (%s)\n", input[[paste0("x_variable_", i)]], x_var_code, 
                  input[[paste0("y_variable_", i)]], y_var_code))
      
      # Country selection
      if (input[[paste0("global_countries_", i)]]) {
        available_countries <- countries
      } else {
        available_countries <- input[[paste0("country_", i)]]
      }
      
      # Income filter
      if (input[[paste0("filter_income_", i)]] && 
          !is.null(input[[paste0("income_category_", i)]]) &&
          !"ALL" %in% input[[paste0("income_category_", i)]]) {
        income_countries <- unique(unlist(income_by_status[input[[paste0("income_category_", i)]]]))
        available_countries <- intersect(available_countries, income_countries)
      }
      
      # Check data source availability
      x_source <- var_sources[[x_var_code]]
      y_source <- var_sources[[y_var_code]]
      
      cat(sprintf("Sources - X: %s, Y: %s\n", x_source, y_source))
      
      if (x_source == "life_table" || y_source == "life_table") {
        available_countries <- intersect(available_countries, life_countries)
      }
      if (x_source == "country_table" || y_source == "country_table") {
        available_countries <- intersect(available_countries, country_countries)
      }
      
      cat(sprintf("Final countries: %d\n", length(available_countries)))
      
      if (length(available_countries) == 0) {
        return(list(data = NULL, countries = NULL, warning = "No countries match all filter criteria",
                    x_var = x_var_code, y_var = y_var_code))
      }
      
      # Fetch data
      year_min <- input[[paste0("year_range_", i)]][1]
      year_max <- input[[paste0("year_range_", i)]][2]
      age_min <- input[[paste0("age_range_", i)]][1]
      age_max <- input[[paste0("age_range_", i)]][2]
      
      # Determine source
      both_life <- (x_source == "life_table" && y_source == "life_table")
      has_age <- (x_var_code == "Age" || y_var_code == "Age")
      both_country <- (x_source == "country_table" && y_source == "country_table")
      year_with_country <- ((x_var_code == "Year" && y_source == "country_table") ||
                            (y_var_code == "Year" && x_source == "country_table"))
      year_with_life <- ((x_var_code == "Year" && y_source == "life_table") ||
                         (y_var_code == "Year" && x_source == "life_table"))
      
      if (both_life || has_age) {
        cat("Source: life_table\n")
        plot_data <- life_table[.(available_countries)][
          Year >= year_min & Year <= year_max &
          Age >= age_min & Age <= age_max
        ]
      } else if (both_country || year_with_country) {
        cat("Source: country_table\n")
        plot_data <- country_table[.(available_countries)][
          Year >= year_min & Year <= year_max
        ]
      } else if (year_with_life) {
        cat("Source: life_table (Age=0)\n")
        plot_data <- life_table[.(available_countries)][
          Year >= year_min & Year <= year_max & Age == 0
        ]
      } else {
        cat("Source: merged\n")
        life_sub <- life_table[.(available_countries)][
          Year >= year_min & Year <= year_max &
          Age >= age_min & Age <= age_max
        ]
        country_sub <- country_table[.(available_countries)][
          Year >= year_min & Year <= year_max
        ]
        plot_data <- merge(life_sub, country_sub, by = c("ISO3", "Year"), all = FALSE)
      }
      
      cat(sprintf("Rows: %d\n======================\n\n", nrow(plot_data)))
      
      # Pre-order data
      if (!is.null(plot_data) && nrow(plot_data) > 0) {
        if (x_var_code == "Age" || x_var_code == "Year") {
          setorderv(plot_data, c("ISO3", x_var_code))
        }
      }
      
      list(data = plot_data, countries = available_countries, warning = NULL,
           x_var = x_var_code, y_var = y_var_code)
    })
    
    # Main plot rendering function (extracted for reuse in download)
    create_plot <- function() {
      result <- filtered_data()
      
      if (!is.null(result$warning)) {
        plot.new()
        text(0.5, 0.5, result$warning, col = "red", cex = 1.5)
        return()
      }
      
      plot_data <- result$data
      available_countries <- result$countries
      x_var <- result$x_var
      y_var <- result$y_var
      
      if (is.null(plot_data) || nrow(plot_data) == 0) {
        plot.new()
        text(0.5, 0.5, "No data available", col = "red", cex = 1.5)
        return()
      }
      
      # Get labels
      x_lab <- input[[paste0("x_label_", i)]]
      if (is.null(x_lab) || x_lab == "") x_lab <- input[[paste0("x_variable_", i)]]
      
      y_lab <- input[[paste0("y_label_", i)]]
      if (is.null(y_lab) || y_lab == "") y_lab <- input[[paste0("y_variable_", i)]]
      
      plot_title <- input[[paste0("plot_title_", i)]]
      if (is.null(plot_title) || plot_title == "") {
        plot_title <- paste(input[[paste0("y_variable_", i)]], "vs", input[[paste0("x_variable_", i)]])
      }
      
      plot_type <- input[[paste0("plot_type_", i)]]
      if (is.null(plot_type)) plot_type <- "line"
      
      n_countries <- length(available_countries)
      
      # Calculate axis limits
      x_range <- range(plot_data[[x_var]], na.rm = TRUE)
      y_range <- range(plot_data[[y_var]], na.rm = TRUE)
      y_padding <- (y_range[2] - y_range[1]) * 0.05
      y_lim <- c(y_range[1] - y_padding, y_range[2] + y_padding)
      
      # Calculate legend dimensions
      if (n_countries == 1 && (x_var == "Age" || y_var == "Age")) {
        legend_rows <- 1
        n_cols_legend <- 5
      } else if (n_countries > 1) {
        n_cols_legend <- min(ceiling(n_countries / 2), 6)
        legend_rows <- ceiling(n_countries / n_cols_legend)
      } else {
        legend_rows <- 0
        n_cols_legend <- 1
      }
      
      bottom_margin <- 5 + (legend_rows * 2.5)
      par(mar = c(bottom_margin, 4, 4, 2) + 0.1)
      
      # SINGLE COUNTRY
      if (n_countries == 1) {
        country_data <- plot_data[ISO3 == available_countries[1]]
        
        if (x_var == "Age" || y_var == "Age") {
          years_available <- sort(unique(country_data$Year))
          
          if (length(years_available) >= 5) {
            n_yrs <- length(years_available)
            quartile_years <- c(
              years_available[1],
              years_available[round(n_yrs * 0.25)],
              years_available[round(n_yrs * 0.50)],
              years_available[round(n_yrs * 0.75)],
              years_available[n_yrs]
            )
            colors <- colorRampPalette(c("#2166AC", "#4393C3", "#92C5DE", "#F4A582", "#D6604D"))(5)
            
            plot(1, type = "n", xlim = x_range, ylim = y_lim,
                 xlab = x_lab, ylab = y_lab, main = plot_title,
                 bty = "l", las = 1, cex.lab = 1.2, cex.main = 1.3)
            
            for (j in 1:5) {
              year_data <- country_data[Year == quartile_years[j]]
              if (nrow(year_data) > 0) {
                if (plot_type == "line") {
                  lines(year_data[[x_var]], year_data[[y_var]], col = colors[j], lwd = 2.5)
                } else {
                  points(year_data[[x_var]], year_data[[y_var]], col = colors[j], pch = 19, cex = 1.2)
                }
              }
            }
            
            legend(x = "bottom", 
                   legend = paste(quartile_years, c("(Start)", "(Q1)", "(Median)", "(Q3)", "(End)")),
                   col = colors, lwd = 2.5, pch = if(plot_type == "scatter") 19 else NA,
                   bty = "n", ncol = 5, cex = 0.9,
                   xpd = TRUE, inset = c(0, -0.35))
          } else {
            plot(country_data[[x_var]], country_data[[y_var]],
                 type = if(plot_type == "line") "l" else "p",
                 col = "#2166AC", lwd = 2.5, pch = 19, cex = 1.2,
                 xlim = x_range, ylim = y_lim,
                 xlab = x_lab, ylab = y_lab, main = plot_title,
                 bty = "l", las = 1, cex.lab = 1.2, cex.main = 1.3)
          }
        } else {
          plot(country_data[[x_var]], country_data[[y_var]],
               type = if(plot_type == "line") "l" else "p",
               col = "#2166AC", lwd = 2.5, pch = 19, cex = 1.2,
               xlim = x_range, ylim = y_lim,
               xlab = x_lab, ylab = y_lab, main = plot_title,
               bty = "l", las = 1, cex.lab = 1.2, cex.main = 1.3)
        }
        
      # MULTIPLE COUNTRIES
      } else {
        colors <- brewer.pal(min(n_countries, 8), "Set2")
        if (n_countries > 8) {
          colors <- rep(colors, ceiling(n_countries / 8))[1:n_countries]
        }
        
        plot(1, type = "n", xlim = x_range, ylim = y_lim,
             xlab = x_lab, ylab = y_lab, main = plot_title,
             bty = "l", las = 1, cex.lab = 1.2, cex.main = 1.3)
        
        if (x_var == "Age" || y_var == "Age") {
          years_available <- sort(unique(plot_data$Year))
          n_years <- length(years_available)
          
          if (n_years <= 5) {
            selected_years <- years_available
          } else {
            selected_years <- c(
              years_available[1],
              years_available[round(n_years * 0.25)],
              years_available[round(n_years * 0.50)],
              years_available[round(n_years * 0.75)],
              years_available[n_years]
            )
          }
          
          for (j in 1:n_countries) {
            country <- available_countries[j]
            country_data <- plot_data[ISO3 == country]
            
            for (yr in selected_years) {
              year_data <- country_data[Year == yr]
              if (nrow(year_data) > 0) {
                if (plot_type == "line") {
                  lines(year_data[[x_var]], year_data[[y_var]], col = colors[j], lwd = 2.5)
                } else {
                  points(year_data[[x_var]], year_data[[y_var]], col = colors[j], pch = 19, cex = 1.0)
                }
              }
            }
          }
        } else {
          for (j in 1:n_countries) {
            country <- available_countries[j]
            country_data <- plot_data[ISO3 == country]
            
            if (nrow(country_data) > 0) {
              if (plot_type == "line") {
                lines(country_data[[x_var]], country_data[[y_var]], col = colors[j], lwd = 2.5)
              } else {
                points(country_data[[x_var]], country_data[[y_var]], col = colors[j], pch = 19, cex = 1.0)
              }
            }
          }
        }


# Calculate dynamic inset based on number of legend rows
# Formula: base inset (0.25) + 0.08 per additional row
legend_inset <- -0.25 - (legend_rows * 0.08)

legend(x = "bottom",
       title = "Countries",
       legend = available_countries,
       col = colors[1:n_countries],
       lwd = if(plot_type == "line") 2.5 else NA,
       pch = if(plot_type == "scatter") 19 else NA,
       bty = "n",
       ncol = n_cols_legend,
       cex = 0.8,
       xpd = TRUE,
       inset = c(0, legend_inset))  
      }
    }
    
    # Render plot
    output[[paste0("main_plot_", i)]] <- renderPlot({
      create_plot()
    })
    
    # Download handler
    output[[paste0("download_plot_", i)]] <- downloadHandler(
      filename = function() {
        tab_name <- input[[paste0("tab_name_", i)]]
        if (is.null(tab_name) || tab_name == "") {
          tab_name <- paste("Analysis", i)
        }
        paste0(gsub(" ", "_", tab_name), "_", Sys.Date(), ".png")
      },
      content = function(file) {
        png(file, width = 1200, height = 800, res = 120)
        create_plot()
        dev.off()
      }
    )
  })
}

# Run the application 
shinyApp(ui = ui, server = server, options = list(
  port = 7398,
  host = "127.0.0.1"
))