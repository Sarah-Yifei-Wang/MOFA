
#' @title Calculate variance explained in a MOFA model for each view and latent factor
#' @name calculateVarianceExplained
#' @description Method to calculate variance explained in a MOFA model for each view and latent factor.
#' As a measure of variance explained the coefficient of determination, given by 1 - SS_res/SS_total.
#' For non-gaussian views the calculations are basedon the gaussian pseudo-data. 
#' The resulting measures per factor and overall are plotted as a heatmap and barplot by default.
#' @param object a \code{\link{MOFAmodel}} object.
#' @param views Views to use, default is "all"
#' @param factors Latent variables or factores to use, default is "all"
#' @param plotit boolean, wether to produce a plot (default true)
#' @param perFeature boolean, whether to calculate in addition variance explained per feature (and factor) (default FALSE)
#' @details fill this
#' @return a list containing list of R2 for all gaussian views and list of BS for all binary views
#' @import pheatmap gridExtra ggplot2 gtable
#' @export

calculateVarianceExplained <- function(object, views="all", factors="all", plotit=T, perFeature=F, InterceptLFasNull=F) {
  
  # Define views
  if (paste0(views,sep="",collapse="") =="all") { 
    views <- viewNames(object) 
  } else {
    stopifnot(all(views %in% viewNames(object)))  
  }
  M <- length(views)

  # Define factors
  if (paste0(factors,sep="",collapse="") == "all") { 
    factors <- factorNames(object) 
    #old object are not compatible with factro names
    if(is.null(factors)) factors <- 1:ncol(getExpectations(object,"Z","E"))
  } else {
    stopifnot(all(factors %in% factorNames(object)))  
  }
  K <- length(factors)

  # Collect relevant expectations
  SW <- getExpectations(object,"SW","E")
  Z <- getExpectations(object,"Z","E")
  Y <- getExpectations(object,"Y","E")


  # Calculate predictions under the  MOFA model using all or a single factor
    Ypred_m <- lapply(views, function(m) Z%*%t(SW[[m]])); names(Ypred_m) <- views
    Ypred_mk <- lapply(views, function(m) sapply(factors, function(k) Z[,k]%*%t(SW[[m]][,k]) ) )
    names(Ypred_mk) <- views
    
  # Calculate prediction under the null model (mean only)
    NullModel <- lapply(views, function(m) apply(Y[[m]],2,mean,na.rm=T))
    NullModel <- lapply(views, function(m)  if(InterceptLFasNull) unique(Ypred_mk[[m]][,1]) else apply(Y[[m]],2,mean,na.rm=T))
    names(NullModel) <- views
    resNullModel <- lapply(views, function(m) sweep(Y[[m]],2,NullModel[[m]],"-"))
    names(resNullModel) <- views
    
  #remove intercept factor if present
  if(model@ModelOpts$learnMean) factorsNonconst <- factors[-1] else  factorsNonconst <- factors
    
  # Calculate coefficient of determination
    # per view
     fvar_m <- sapply(views, function(m) 1 - sum((Y[[m]]-Ypred_m[[m]])**2, na.rm=T) / sum(resNullModel[[m]]**2, na.rm=T))
    # per view and feature
    if(perFeature)
      fvar_md <- lapply(views, function(m) 1 - colSums((Y[[m]]-Ypred_m[[m]])**2,na.rm=T) / colSums(resNullModel[[m]]**2,na.rm=T))
    
    # per factor and view
    fvar_mk <- sapply(views, function(m) sapply(factorsNonconst, function(k) 1 - sum((resNullModel[[m]]-Ypred_mk[[m]][,k])**2, na.rm=T) / sum(resNullModel[[m]]**2, na.rm=T) ))
    # per factor and view and feature
    if(perFeature)
      fvar_mdk <- lapply(views, function(m) sapply(factorsNonconst, function(k) 1 - colSums((resNullModel[[m]]-Ypred_mk[[m]][,k])**2,na.rm=T) / colSums(resNullModel[[m]]**2,na.rm=T)))
    
    # Set names
    names(fvar_m) <- views
    if(perFeature){
      names(fvar_md) <- views
      names(fvar_mdk) <- views
      for(i in names(fvar_md)) names(fvar_md[[i]]) <- colnames(object@TrainData[[i]])
      for(i in names(fvar_mdk)) rownames(fvar_mdk[[i]]) <- colnames(object@TrainData[[i]])
    }
    colnames(fvar_mk) <- views
    rownames(fvar_mk) <- factorsNonconst 
  
    # Heatmap with coefficient of determination (R2) per factor and view
    # hm <- pheatmap::pheatmap(fvar_mk, silent=T,
    #                       color = colorRampPalette(c("white","darkblue"))(100), 
    #                       cluster_cols = T, cluster_rows = F,
    #                       main = "Variance explained per view and factor",
    #                       treeheight_col = 10)
    
    #Melting data so we can plot it with GGplot
    fvar_mk_df <- melt(fvar_mk,varnames  = c("factor","view"))
    
    #Resetting factors
    fvar_mk_df$factor <- factor(fvar_mk_df$factor)
    hc<-hclust(dist(t(fvar_mk)))
    fvar_mk_df$view <- factor(fvar_mk_df$view, levels = colnames(fvar_mk)[hc$order])
    fvar_mk_df$factor <- factor(fvar_mk_df$factor, levels = rev(factorsNonconst))
    
    #Creating the plot itself
    hm <- ggplot(fvar_mk_df,aes(view,factor)) + geom_raster(aes(fill=value)) +
      guides(fill=guide_colorbar("R2")) +
      # scale_y_discrete(position = "right") +
      scale_fill_gradientn(colors=c("white","darkblue"),guide="colorbar") +
      theme(axis.title.x = element_blank(),
            # axis.text.x = element_blank(),
            axis.line = element_blank(),
            axis.ticks =  element_blank())+
      ggtitle("Factor-wise variance explained per view")
      
    
    fvar_m_df <- data.frame(view=names(fvar_m), R2=fvar_m)
    fvar_m_df$view <- factor(fvar_m_df$view, levels = colnames(fvar_mk)[hc$order])
    
    # Barplot with coefficient of determination (R2) per view
    bplt <- ggplot( fvar_m_df, aes(x=view, y=R2)) + 
      geom_bar(stat="identity", fill="deepskyblue4", width=0.9) +
      xlab("") + 
      # scale_y_continuous(position = "right")+
      # theme_minimal() +
      theme(plot.margin = unit(c(1,2.4,0,0), "cm")) +
      ggtitle("Total variance explained per view")
    
    # Join the two plots
    # Need to fix alignment using e.g. gtable...
    # gg_R2 <- gridExtra::arrangeGrob(hm$gtable, bplt, ncol=1, heights=c(10,5) )
    gg_R2 <- gridExtra::arrangeGrob(hm, bplt, ncol=1, heights=c(length(factorsNonconst),7) )
    if (plotit) grid.arrange(gg_R2)
   
  # Store results
    R2_list <- list(
      R2Total = fvar_m,
      R2PerFactor = fvar_mk, 
      measure = "R2")
    if(perFeature){
      R2_list$R2PerFactorAndFeature = fvar_mdk
      R2_list$R2PerFeature = fvar_md
    }
  
  return(R2_list)
 
}
