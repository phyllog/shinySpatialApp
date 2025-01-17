#' Generate the Rmd reproducible report
#'
#' @param input list of inputs.
#' @param geoms sf object selected.
#' @param outFileName file name (optional).
#' @param dirOut output directory.
#' @param dirIn input directory.
# 
renderReport <- function(input, geoms, outFileName = NULL, dirOut = "output", 
  dirIn = "Rmd") { 
  
  #time report:
  renderTimeStart <- Sys.time()
  
  # rm all html 
  clear_www_html()
  clear_output()

  # lang of the report, set ok to check for each lang
  langs <- rev(input$report_lang)
  numLang <- length(langs)
  ok <- rep(FALSE, numLang)
  
  if (is.null(langs)) {
    msg <- "Please select at least one language"
    return(list(msg = msg, ok = FALSE, html = "empty_report.html"))
  }
  
  # check and save geom 
  msgInfo("Saving geoms")
  if (is.null(geoms)) {
    msg <- "Please define areas of interest"
    return(list(msg = msg, ok = FALSE, html = "empty_report.html"))
  } else {
    geomFile <- save_geom(geoms, dirOut = dirOut)
  }
  
  # nasty trick (due to current rmarkdown behavior) to name final file properly 
  #if (!is.null(outFileName) & outFileName != "") {
  #  outFileName <- rep(outFileName, 10)
  #} else outFileName <- rep("report_SMR", 10)
  
  if (is.null(outFileName) | outFileName == "") {
    outFileName <- "report_SMR"
  }
  
  
  # loop over language 
  for (i in seq_len(numLang)) {
    msgInfo(paste0("Creating report (", langs[i], ")"))
    langOutFile <- paste0(outFileName, "_", langs[i])
    inFile <- glue("{dirIn}/intro_{langs[i]}.Rmd") 

    # Section(s) to be added
    s_main <- s_ebsa <- s_appendix <- NULL
    if (!is.null(input$main_sections)) {
      s_main <- main_parts(input$main_sections, langs[i])
    } 
    if (!is.null(input$extra_sections)) {
      s_ebsa <- planning_part(any(input$extra_sections == 1), langs[i])
      s_appendix <- habitat_part(any(input$extra_sections == 2), langs[i])
    }
    
    # fill out .Rmd file in outDir before rendering
    rmdOut <- glue("{dirOut}/{basename(inFile)}") 
    template <- readLines(inFile)
    whiskerData <- c(
      input,
      path_to_geoms = geomFile$relRmd,
      add_main_sections = add_sections(s_main, dirIn, dirOut),
      add_ebsa_section = add_sections(s_ebsa, dirIn, dirOut),
      add_appendix = add_sections(s_appendix, dirIn, dirOut)
    )  
    writeLines(whisker::whisker.render(template, whiskerData), rmdOut)
    # First rendering
    ok[i] <- tryCatch({
        rmarkdown::render(rmdOut,
         output_dir = dirOut,
         output_file = langOutFile,
         quiet = FALSE)
      TRUE # flag to show report in app.  
      }, 
      error = function(x) FALSE
    )
  
  } # end of language loop
  
  renderTimeEnd <- Sys.time()
  msgInfo("Report render time:")
  msgInfo(renderTimeEnd - renderTimeStart)
  msgInfo("Render complete")
  
  if (all(ok)) {
    # this is done to generate an html preview (see "report" tab)
    htmlName <- switch_ext(basename(inFile), "html") 
    htmlOut <- paste(dirOut, "/", langOutFile, ".html", sep="")
    # do not render again if html has already been generated
    if (file.exists(htmlOut)) {
      file.copy(htmlOut, glue(here::here("app", "www/{htmlName}")))
      msg <- "Successfully rendered."
    } else {
      msg <- "Issue while rendering"
      rmdOut <- htmlName <- NULL
    }
  } else {
    msg <- "Issue while rendering"
    rmdOut <- htmlName <- NULL
  }

  list(msg = msg, ok = all(ok), html = htmlName)
}

# add rmd code chunk to add section (using child documents)
add_sections <- function(fileNames = NULL, dirIn, dirOut) {
  if (!is.null(fileNames)) {
    rmdChildNames <- paste0("'", fileNames, "'") 
    # copy/paste files
    file.copy(paste0(dirIn, "/", fileNames), dirOut)
    #
    glue("```{{r, child = c({glue_collapse(rmdChildNames, sep = ', ')})}}\n```")
  } else fileNames
}

main_parts <- function(sectionNum, langChoice = c("EN", "FR")) {
  langChoice <- match.arg(langChoice)
  sectionName <- c(
    "report_SARA",
    "report_fish",
    "report_cetaceans"
  )[as.numeric(sectionNum)]
  paste0(sectionName, "_", langChoice, ".Rmd")
}

planning_part <- function(includSection, langChoice = c("EN", "FR")) {
  langChoice <- match.arg(langChoice)
  if (includSection) {
    return(glue("report_planning_{langChoice}.Rmd"))
  } else {
    return(NULL)
  }
}

habitat_part <- function(includSection, langChoice = c("EN", "FR")) {
  langChoice <- match.arg(langChoice)
  if (includSection) {
    return(glue("report_habitat_{langChoice}.Rmd"))
  } else {
    return(NULL)
  }
}

save_geom <- function(geoms, dirOut = "output", geomFileName ="geoms_slc.geojson") {
  st_write(geoms, glue("{dirOut}/{geomFileName}"), delete_dsn = TRUE, quiet = TRUE)
  list(relRoot = glue("{dirOut}/{geomFileName}"), relRmd = geomFileName)
}