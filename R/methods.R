##################################################################
## addAssay: Extension accessor for SummarizedExperiment object ##
##################################################################
setGeneric(name = "addAssay", def = function(x, ...) standardGeneric("addAssay"))
setMethod(f = "addAssay", signature = "SummarizedExperiment", definition = function(x, value, xName = NULL) {
  listSE <- S4Vectors::SimpleList()
  for (i in seq_along(assays(x))) {
    listSE[[i]] <- assays(x)[[i]]
  }
  listSE[[length(listSE) + 1]] <- value
  names(listSE) <- c(assayNames(x), xName)
  assays(x, withDimnames = FALSE) <- listSE
  return(x)
})

####################################################################
## addMetadata: Extension accessor for SummarizedExperiment object ##
####################################################################
setGeneric(name = "addMetadata", def = function(x, ...) standardGeneric("addMetadata"))
setMethod(f = "addMetadata", signature = "SummarizedExperiment", definition = function(x, value, xName = NULL) {
  listSE <- list()
  for (i in seq_along(metadata(x))) {
    listSE[[i]] <- metadata(x)[[i]]
  }
  listSE[[length(listSE) + 1]] <- value
  names(listSE) <- c(names(metadata(x)), xName)
  metadata(x) <- listSE
  return(x)
})

##############
## SPRdata ##
##############
SPRdata <- function(counts = SimpleList(), rowData = NULL, rowRanges = GRangesList(),
                    cmp = FALSE, targetspath = NULL, SEobj = NULL, SEobjName = "default") {
  if (is.null(SEobj)) {
    if (is.null(targetspath)) {
      targets <- S4Vectors::DataFrame()
    } else {
      targets <- read.delim(targetspath, comment.char = "#")
    }
    if (cmp == FALSE) {
      metadata <- list(version = packageVersion("systemPipeR"))
    } else {
      cmpMA <- systemPipeR::readComp(file = targetspath, format = "matrix", delim = "-")
      metadata <- list(version = packageVersion("systemPipeR"), comparison = cmpMA)
    }
    se <- SummarizedExperiment(
      assays = counts,
      colData = targets,
      metadata = metadata
    )
    if (all(!length(assays(se))==0 & is.null(assayNames(se)))) assayNames(se) <- "counts"
    return(se)
  } else if (!is.null(SEobj)) {
    if (SEobjName == "default") SEobjName <- paste0("assays_", length(assays(SEobj)) + 1)
    sprSE <- addAssay(SEobj, counts, SEobjName)
  }
}

## TODO
## rowData matching with all the assays
## rowRanges
## from sprSE to targets and cmp


## Usage:
# Targets file
# targetspath <- system.file("extdata", "targets.txt", package="systemPipeR")
# targets <- read.delim(targetspath, comment.char = "#")
# cmp <- systemPipeR::readComp(file=targetspath, format="matrix", delim="-")
# ## Count table file
# countMatrixPath <- system.file("extdata", "countDFeByg.xls", package="systemPipeR")
# countMatrix <- read.delim(countMatrixPath, row.names=1)
# 
# ## Create empty SummarizedExperiment
# #library(S4Vectors)
# library(SummarizedExperiment)
# sprSE <- SPRdata()
# class(sprSE)
# sprSE
# metadata(sprSE)
# ## Create an object with targets file and comparison
# sprSE <- SPRdata(cmp=TRUE, targetspath = targetspath)
# sprSE
# metadata(sprSE)
# colData(sprSE)
# assays(sprSE)
# 
# ## Create an object with targets file and comparison and count table
# sprSE <- SPRdata(counts =  countMatrix, cmp=TRUE, targetspath = targetspath, rowRanges = rowRanges)
# sprSE
# metadata(sprSE)
# colData(sprSE)
# assays(sprSE)
# assay(sprSE)
# assayNames(sprSE)
# ## Add more count table results
# dds <- DESeq2::DESeqDataSetFromMatrix(countData = countMatrix,
#                               colData = targets,
#                               design = ~Factor)
# rld <- DESeq2::rlog(dds, blind=FALSE)
# sprSE <- SPRdata(counts = assay(rld), SEobj = sprSE)
# sprSE
# metadata(sprSE)
# colData(sprSE)

# sprSE <- addAssay(sprSE, assay(rld), xName="test")
# sprSE <- addMetadata(sprSE, list(targets), xName="targets_original")
