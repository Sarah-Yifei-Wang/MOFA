
################################################
## Functions to compare different MOFA models ##
################################################


#' @title Plot the robustness of the latent factors across diferent trials
#' @name compareModels
#' @description Different objects of \code{\link{MOFAmodel}} are compared in terms of correlation between 
#' their latent factors. The correlation is calculated only on those samples which are present in all models.
#' Ideally, the output should look like a block diagonal matrix, suggesting that all detected factors are robust under different initialisations.
#' If not, it suggests that some factors are weak and not captured by all models.
#' @param models a list containing \code{\link{MOFAmodel}} objects.
#' @param comparison tye of comparison, either 'pairwise' or 'all'
#' @details asd
#' @return Plots a heatmap of correlation of Latent Factors in all models when 'comparison' is 'all'. 
#' Otherwise, for each pair of models, a seperate heatmap is produced comparing one model againt the other.
#' The corresponding correlation matrix or list or pairwise correlation matrices is returned
#' @references fill this
#' @importFrom stats cor
#' @importFrom pheatmap pheatmap
#' @importFrom grDevices colorRampPalette
#' @export

compareModels <- function(models, comparison = "all", ...) {
  
  # Sanity checks
  if(class(models)!="list")
    stop("'models' has to be a list")
  if (!all(sapply(models, function (l) class(l)=="MOFAmodel")))
    stop("Each element of the the list 'models' has to be an instance of MOFAmodel")
  if (!comparison %in% c("all", "pairwise"))
    stop("'comparison' has to be either 'all' or 'pairwise'")
  
  # give generic names if no names present
  if(is.null(names(models))) names(models) <- paste("model", 1: length(models), sep="")
  
  # get latent factors
  LFs <- lapply(seq_along(models), function(modelidx){
    model <- models[[modelidx]]
    Z <- getExpectations(model, 'Z', 'E')
    if(!is.null(model@ModelOpts$learnIntercept)) if(model@ModelOpts$learnIntercept) Z <- Z[,-1]
    if(is.null(rownames(Z))) rownames(Z) <- rownames(model@TrainData[[1]])
    if(is.null(colnames(Z))) 
      if(!is.null(model@ModelOpts$learnIntercept)) {
        if(model@ModelOpts$learnIntercept)  colnames(Z) <- paste("LF", 2:(ncol(Z)+1), sep="")
        }else
          colnames(Z) <- paste("LF", 1:ncol(Z), sep="")
    Z
    })
  for(i in seq_along(LFs)) 
    colnames(LFs[[i]]) <- paste(names(models)[i], colnames(LFs[[i]]), sep="_")
  
  if(comparison=="all") {
    #get common samples between models
    commonSamples <- Reduce(intersect,lapply(LFs, rownames))
    if(is.null(commonSamples)) 
      stop("No common samples in all models for comparison")
    
    #subset LFs to common samples
    LFscommon <- Reduce(cbind, lapply(LFs, function(Z) Z[commonSamples,]))

    # calculate correlation
    corLFs <- cor(LFscommon, use="complete.obs")
    
    #annotation by model
    # modelAnnot <- data.frame(model = rep(names(models), times=sapply(LFs, ncol)))
    # rownames(modelAnnot) <- colnames(LFscommon)
    
    #plot heatmap
    # if(is.null(main)) main <- "Absolute correlation between latent factors"
    pheatmap(abs(corLFs), show_rownames = F,
             color = colorRampPalette(c("white",RColorBrewer::brewer.pal(9,name="YlOrRd")))(100),
             # color=colorRampPalette(c("white", "orange" ,"red"))(100), 
             # annotation_col = modelAnnot, main= main , ...)
             ...)
    
    return(corLFs)
  }
  
  if(comparison=="pairwise"){
    PairWiseCor <- lapply(seq_along(LFs[-length(LFs)]), function(i){
      LFs1<-LFs[[i]]
        sublist <- lapply((i+1):length(LFs), function(j){
          LFs2<-LFs[[j]]
          common_pairwise <- intersect(rownames(LFs1), rownames(LFs2))
          if(is.null(common_pairwise)) {
            warning(paste("No common samples between models",i,"and",j,"- No comparison possible"))
            NA
          }
          else{
          # if(is.null(main)) main <- paste("Absolute correlation between factors in model", i,"and",j)
          corLFs_pairs <- cor(LFs1[common_pairwise,], LFs2[common_pairwise,], use="complete.obs")
          pheatmap(abs(corLFs_pairs),color=colorRampPalette(c("white", "orange" ,"red"))(100), ...)
          corLFs_pairs
          }
        })
        names(sublist) <- names(models)[(i+1):length(LFs)]
        sublist
    })
    names(PairWiseCor) <- names(models[-length(models)])
    return(PairWiseCor)
  }
}