#######################################################################
## Merge BAM files based on factor and return updated SYSargs object ##
#######################################################################
## Useful prior to peak calling in ChIP-Seq or miRNA gene prediction experiments
## where pooling of replicates maximizes depth of read coverage.
## Note: default factor is "Factor"
mergeBamByFactor <- function(args, mergefactor="Factor", overwrite=FALSE, silent=FALSE, ...) {
  if(all(class(args) != "SYSargs" & class(args) != "SYSargs2")) stop("Argument 'x' needs to be assigned an object of class 'SYSargs' OR 'SYSargs2")
  ## SYSargs class
  if(class(args) == "SYSargs") {
    mergefactor <- targetsin(args)[[mergefactor]] 
    targetsin <- targetsin(args)
    ## SYSargs2 class  
  } else if (class(args) == "SYSargs2"){
    mergefactor <- targets.as.df(targets(args))[[mergefactor]]
    targetsin <- targets.as.df(targets(args))
  }
  ## Check validity of input
  allbam <- !grepl("\\.bam$|\\.BAM", infile1(args))
  if(any(allbam)) stop("The following files lack the extension '.bam': ", paste(basename(infile1(args)[allbam]), collapse=", "))
  if(!"FileName" %in% colnames(targetsin)) stop("Name of one column in 'targetsin(arg)' is expected to be 'FileName'.")
  ## Unique values in Factor column of targetsin(args) 
  sample_index <- !duplicated(as.character(mergefactor)); names(sample_index) <- names(infile1(args))
  uniorder <- unique(mergefactor) 
  unifreq <- table(mergefactor)[uniorder] # Important: in order of targetsin(args)!
  if(!any(unifreq >= 2)) warning("Values in Factor column are all unique. Thus, there are no BAM files to merge.")
  ## Store BAM file paths in a list that have >=2 identical values (replicates) in Factor column of targets file
  filelist <- tapply(targetsin$FileName, factor(mergefactor), as.character)
  filelist <- filelist[names(unifreq)] # Assures original order
  ## Create vector containing paths of output BAM files 
  filelist_merge <- filelist[names(unifreq[unifreq>=2])] # Merge only those with >= files
  outname_vec <- character(length(filelist_merge)); names(outname_vec) <- names(filelist_merge)
  for(i in seq(along=outname_vec)) {
    outname <- gsub("\\.bam$|\\.BAM$", "", filelist_merge[[i]][1])
    outname <- paste(outname, "_", names(filelist_merge[i]), ".bam", sep="")
    outname_vec[i] <- outname
  }
  ## If any output BAM file exists and 'overwrite=FALSE' then stop
  file_exists <- file.exists(outname_vec); names(file_exists) <- names(outname_vec) 
  if(any(file_exists) & overwrite==FALSE) stop("The following files exist: ", paste(names(file_exists)[file_exists], collapse=", ") , ". Delete/rename them or set 'overwrite=TRUE'")
  ## Generate collapsed BAM files
  for(i in seq(along=filelist_merge)) {
    mergeBam(filelist_merge[[i]], outname_vec[i], indexDestination=TRUE, overwrite=overwrite)
    if(silent!=TRUE) {
      cat("Merged BAM files:", basename(filelist_merge[[i]]), "and saved to file", basename(outname_vec[i]), "\n\n")
    }
  }
  ## Generate updated SYSargs and SYSargs2 object 
  filelist[names(outname_vec)] <- outname_vec # Assign new file names to proper slots
  outfile_names <- unlist(filelist) 
  args_sub <- args[sample_index]
  ## SYSargs class
  if(class(args) == "SYSargs") {
    targets_out <- targetsout(args_sub)
    targets_out[,"FileName"] <- outfile_names
    rownames(targets_out) <- NULL
    syslist <- list(targetsin=targetsin(args_sub),
                    targetsout=targets_out,
                    targetsheader=targetsheader(args_sub),
                    modules=modules(args_sub), 
                    software="mergeBamByFactor", 
                    cores=cores(args_sub),
                    other=other(args_sub),
                    reference=reference(args_sub),
                    results=results(args_sub),
                    infile1=infile1(args_sub),
                    infile2=infile2(args_sub),
                    outfile1=outfile_names,
                    sysargs=sysargs(args_sub), 
                    outpaths=outfile_names)
    args_sub_out <- as(syslist, "SYSargs")
    ## SYSargs2 class  
  } else if (class(args) == "SYSargs2"){
    out <- sapply(names(outfile_names), function(x) list(outfile_names[[x]]), simplify = F)
    for(i in seq_along(out)){
      names(out[[i]]) <- cwlfiles(args)$step
    }
    # out <- sapply(names(out), function(x) names(out[[x]]) <- cwlfiles(args)$step, simplify = F)
    sys2list <- list(targets=targets(args_sub),  
                     targetsheader=targetsheader(args_sub),
                     modules=as.list(modules(args_sub)),
                     wf=wf(args_sub),
                     clt=clt(args_sub),
                     yamlinput=yamlinput(args_sub), 
                     cmdlist=cmdlist(args_sub),
                     input=input(args_sub),
                     output=out,
                     cwlfiles=cwlfiles(args_sub), 
                     inputvars=inputvars(args_sub)) 
    args_sub_out <- as(sys2list, "SYSargs2")
  }
  return(args_sub_out)
}
## Usage:
# args <- systemArgs(sysma=NULL, mytargets="targets_bam.txt")
# args_merge <- mergeBamByFactor(args, overwrite=TRUE, silent=FALSE)
# writeTargetsout(x=args_merge, file="targets_mergeBamByFactor.txt", overwrite=TRUE) 

############################################################################
## Creat targets file with refence sample, e.g. input sample for ChIP-Seq ##
############################################################################
writeTargetsRef <- function(infile, outfile, silent=FALSE, overwrite=FALSE, ...) {
  ## Import
  headerlines <- readLines(infile)
  targets <- read.delim(infile, comment.char = "#")
  ## Check for expected input
  if(!c("SampleReference") %in% colnames(targets)) stop("Targets file lacks SampleReference column")
  if(!c("FileName") %in% colnames(targets)) stop("Targets file lacks FileName column")
  if(all(c("FileName1", "FileName2") %in% colnames(targets))) stop("Targets file is expected to have only one FileName column")
  if(file.exists(outfile) & overwrite==FALSE) stop(paste("I am not allowed to overwrite files; please delete existing file:", outfile, "or set 'overwrite=TRUE'")) 
  testv <- as.character(targets$SampleReference); testv <- testv[!is.na(testv)]; testv <- testv[testv!=""] 
  myfiles <- as.character(targets$FileName); names(myfiles) <- as.character(targets$SampleName)
  if(!all(testv %in% names(myfiles))) stop(paste("Value(s)", paste(testv[!testv %in% names(myfiles)], collapse=", "), "from SampleReference column have no matches in SampleName column!"))
  ## Rearrange targets file
  targets <- data.frame(FileName1=targets$FileName, FileName2=NA, targets[,2:length(targets[1,])])
  targets[,"FileName2"] <- myfiles[as.character(targets$SampleReference)]
  targets <- targets[!is.na(as.character(targets$SampleReference)), , drop=FALSE] 
  targets <- targets[targets$SampleReference!="", , drop=FALSE] 
  ## Export targets file including header lines
  headerlines <- headerlines[grepl("^#", headerlines)]
  targetslines <- c(paste(colnames(targets), collapse="\t"), apply(targets, 1, paste, collapse="\t"))
  writeLines(c(headerlines, targetslines), outfile, ...)
  if(silent!=TRUE) cat("\t", "Modified", infile, "file with sample-wise reference has been written to outfile", outfile, "\n") 
}
## Usage:
# writeTargetsRef(infile="~/targets.txt", outfile="~/targets_refsample.txt", silent=FALSE, overwrite=FALSE)

########################################################
## Iterative read counting over different range files ##
########################################################
## Convenience function to perform read counting over serveral different
## range sets, e.g. peak ranges or feature types
countRangeset <- function(bfl, args, format="tabular", ...) {
  ## Input validity checks
  if(class(bfl)!="BamFileList") stop("'bfl' needs to be of class 'BamFileList'.")
  if(all(class(args) != "SYSargs" & class(args) != "SYSargs2")) stop("Argument 'args' needs to be assigned an object of class 'SYSargs' OR 'SYSargs2")
  absent_peak_file <- infile1(args)[!file.exists(infile1(args))]
  if(length(absent_peak_file)!=0) stop("The following files assigned to 'infile1(args)' do not exist: ", paste(basename(absent_peak_file), collapse=", ")) 
  ## Perform read counting for each peak set
  ## SYSargs class
  if(class(args) == "SYSargs") {
    countDFnames <- outpaths(args)
    ## SYSargs2 class  
  } else if (class(args) == "SYSargs2"){
    countDFnames <- subsetWF(args , slot="output", subset=1, index=1)
  }
  for(i in seq(along=infile1(args))) {
    if(format=="tabular") {
      df <- read.delim(infile1(args)[i],comment.char = "#")
      peaks <- as(df, "GRanges")
    } else if(format=="bed") {
      peaks <- import.bed(infile1(args)[i])
    } else {
      stop("Input file format not supported.")
    }
    names(peaks) <- paste0(as.character(seqnames(peaks)), "_", start(peaks), "-", end(peaks))
    peaks <- split(peaks, names(peaks))
    countDF <- summarizeOverlaps(peaks, bfl, ...)
    countDF <- assays(countDF)$counts
    write.table(countDF, countDFnames[i], col.names=NA, quote=FALSE, sep="\t")
    cat("Wrote count result", i, "to", basename(countDFnames[i]), "\n")
  }
  return(countDFnames)
}
## Usage:
# countDFnames <- countRangeset(bfl, args, mode="Union", ignore.strand=TRUE)

################################################################################
## Iterative edgeR/DESeq2 analysis over counts sets from different range sets ##
################################################################################
## Convenience function to iterate over several count sets generated by
## countRangeset() or similar utilities 
runDiff <- function(args, diffFct, targets, cmp, dbrfilter, ...) {
  if(all(class(args) != "SYSargs" & class(args) != "SYSargs2")) stop("Argument 'args' needs to be assigned an object of class 'SYSargs' OR 'SYSargs2")
  countfiles <- infile1(args)
  ## Input validity checks
  absent_count_files <- countfiles[!file.exists(countfiles)]
  if(length(absent_count_files)!=0) stop("The following files assigned to 'countfiles' do not exist: ", paste(basename(absent_count_files), collapse=", ")) 
  ## Perform differential analysis
  ## SYSargs class
  if(class(args) == "SYSargs") {
    dbrDFnames <- outpaths(args)
    ## SYSargs2 class  
  } else if (class(args) == "SYSargs2"){
    dbrDFnames <- subsetWF(args , slot="output", subset=1, index=1)
  }
  dbrlists <- list()
  for(i in seq(along=dbrDFnames)) {
    countDF <- read.delim(countfiles[i], row.names=1)
    edgeDF <- diffFct(countDF=countDF, targets, cmp, ...)
    write.table(edgeDF, dbrDFnames[i], quote=FALSE, sep="\t", col.names = NA)
    pdf(paste0(dbrDFnames[i], ".pdf"))
    DBR_list <- filterDEGs(degDF=edgeDF, filter=dbrfilter)
    dev.off()
    dbrlists <- c(dbrlists, list(DBR_list))
    names(dbrlists)[i] <- names(dbrDFnames[i]) 
    cat("Wrote count result", i, "to", basename(dbrDFnames[i]), "\n")
    cat("Saved plot", i, "to", basename(paste0(dbrDFnames[i], ".pdf")), "\n")
  }
  return(dbrlists)
}
## Usage:
# dbrlist <- runDiff(args, diffFct=run_edgeR, targets=targetsin(args_bam), cmp=cmp[[1]], independent=TRUE, dbrfilter=c(Fold=2, FDR=1))
# dbrlist <- runDiff(args, diffFct=run_edgeR, targets=ttargets.as.df(targets(args_bam)), cmp=cmp[[1]], independent=TRUE, dbrfilter=c(Fold=2, FDR=1))

###########################################################
## (A) olRanges Function for IRanges and GRanges Objects ##
###########################################################
##  Identify Range Overlaps 
olRanges <- function(query, subject, output="gr") {
  ## Input check
  if(!((class(query)=="GRanges" & class(subject)=="GRanges") | (class(query)=="IRanges" & class(subject)=="IRanges"))) {
    stop("Query and subject need to be of same class, either GRanges or IRanges!")
  }
  ## Find overlapping ranges
  if(class(query)=="GRanges") {
    seqlengths(query) <- rep(NA, length(seqlengths(query)))
    seqlengths(subject) <- rep(NA, length(seqlengths(subject)))
  }
  olindex <- as.matrix(findOverlaps(query, subject))
  query <- query[olindex[,1]]
  subject <- subject[olindex[,2]]
  olma <- cbind(Qstart=start(query), Qend=end(query), Sstart=start(subject), Send=end(subject))
  ## Pre-queries for overlaps
  startup <- olma[,"Sstart"] < olma[,"Qstart"]
  enddown <- olma[,"Send"] > olma[,"Qend"]
  startin <- olma[,"Sstart"] >= olma[,"Qstart"] & olma[,"Sstart"] <= olma[,"Qend"]
  endin <- olma[,"Send"] >= olma[,"Qstart"] & olma[,"Send"] <=  olma[,"Qend"]
  ## Overlap types
  olup <- startup & endin
  oldown <- startin & enddown
  inside <- startin & endin 
  contained <- startup & enddown
  ## Overlap types in one vector
  OLtype <- rep("", length(olma[,"Qstart"]))
  OLtype[olup] <- "olup"
  OLtype[oldown] <- "oldown"
  OLtype[inside] <- "inside" 
  OLtype[contained] <- "contained"
  ## Overlap positions
  OLstart <- rep(0, length(olma[,"Qstart"]))
  OLend <- rep(0, length(olma[,"Qstart"]))
  OLstart[olup] <- olma[,"Qstart"][olup]
  OLend[olup] <- olma[,"Send"][olup]
  OLstart[oldown] <- olma[,"Sstart"][oldown]
  OLend[oldown] <- olma[,"Qend"][oldown]
  OLstart[inside] <- olma[,"Sstart"][inside]
  OLend[inside] <- olma[,"Send"][inside]
  OLstart[contained] <- olma[,"Qstart"][contained]
  OLend[contained] <- olma[,"Qend"][contained]
  ## Absolute and relative length of overlaps
  OLlength <- (OLend - OLstart) + 1
  OLpercQ <- OLlength/width(query)*100
  OLpercS <- OLlength/width(subject)*100
  ## Output type
  oldf <- data.frame(Qindex=olindex[,1], Sindex=olindex[,2], olma, OLstart, OLend, OLlength, OLpercQ, OLpercS, OLtype)
  if(class(query) == "GRanges") {
    oldf <- cbind(space=as.character(seqnames(query)), oldf)
  }
  if(output=="df") {
    return(oldf)
  }
  if(output=="gr") {
    if(class(query)=="GRanges") {
      elementMetadata(query) <- cbind(as.data.frame(elementMetadata(query)), oldf)
    }
    if(class(query)=="IRanges") {
      query <- GRanges(seqnames = Rle(rep("dummy", length(query))), ranges = IRanges(start=oldf[,"Qstart"], end=oldf[,"Qend"]), strand = Rle(strand(rep("+", length(query)))), oldf)
    }
    return(query)
  }
}

## Run olRanges function
## Sample Data Sets
# grq <- GRanges(seqnames = Rle(c("chr1", "chr2", "chr1", "chr3"), c(1, 3, 2, 4)), 
#                ranges = IRanges(seq(1, 100, by=10), end = seq(30, 120, by=10)), 
#                strand = Rle(strand(c("-", "+", "-")), c(1, 7, 2)))
# grs <- shift(grq[c(2,5,6)], 5)
# olRanges(query=grq, subject=grs, output="df") 
# olRanges(query=grq, subject=grs, output="gr") 