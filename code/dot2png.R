suppressWarnings(suppressMessages(library(DiagrammeR)))
suppressWarnings(suppressMessages(library(DiagrammeRsvg)))
suppressWarnings(suppressMessages(library(rsvg)))
args = commandArgs(trailingOnly = TRUE)
print(args)
png::writePNG(rsvg(charToRaw(export_svg(grViz(here::here(paste0(args[1],"/make.dot")))))), 
              here::here(paste0(args[2],"/make.png")))
