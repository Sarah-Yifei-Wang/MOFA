
########################################
## Functions to visualise the weights ##
########################################

#' @title plotWeightsHeatmap: show heatmap of the factor loadings in a specific view
#' @name plotWeightsHeatmap
#' @description Function to visualize loadings for a given set of factors in a given view. This is useful to see the overall pattern of the weights but it is not very useful to characterise the factors.
#'  If you want to individually look at the top weights for a given factor we recommend the function showAllWeights and showTopWeights
#' @param object a \code{\link{MOFAmodel}} object.
#' @param view view name
#' @param features name of the features to include (default: "all")
#' @param factors name of the factors to include (default: "all")
#' @param threshold threshold on absolute weight values, features/factors that are below this threshold in all factors/features are removed
#' @param color to fill 
#' @param breaks to fill
#' @param ... further arguments that can be passed to pheatmap
#' @details fill this
#' @return fill this
#' @import pheatmap
#' @importFrom RColorBrewer brewer.pal 
#' @importFrom grDevices colorRampPalette
#' @export
plotWeightsHeatmap <- function(object, view, features = "all", factors = "all", threshold = 0, color = NULL, breaks = NULL, ...) {
  
  # Sanity checks
  if (class(object) != "MOFAmodel") stop("'object' has to be an instance of MOFAmodel")
  stopifnot(all(view %in% viewNames(object)))  
  
  # Define factors
  factors <- as.character(factors)
  if (paste0(factors,collapse="")=="all") { 
    factors <- factorNames(object) 
    # if(is.null(factors)) factors <- 1:ncol(getExpectations(object,"Z"))
  } else {
    stopifnot(all(factors %in% factorNames(object)))  
  }
  
  # Remove intercept factor
  if(object@ModelOpts$learnIntercept==T) { factors <- factors[factors != factorNames(object)[1]] }
  
  # Define features
  if (paste(features,collapse="")=="all") { 
    features <- featureNames(object)[[view]]
  } else {
    stopifnot(all(features %in% featureNames(object)[[view]]))  
  }

  # Get relevant data
  # W <- getExpectations(object,"SW")[[view]][features,factors]
  W <- getWeights(object, views=view, factors=factors)[[1]][features,]
  

  # Set title
  # if (is.null(main)) { main <- paste("Loadings of Latent Factors on", view) }
  
  # set colors and breaks if not specified
  if (is.null(color) & is.null(breaks)) {
    palLength <- 100
    minV <- min(W)
    maxV <- max(W)
    color <- colorRampPalette(colors=c("black", "blue", "white", "orange","red"))(palLength)
    breaks <- c(seq(minV, 0, length.out=ceiling(palLength/2) + 1), 
                seq(maxV/palLength,maxV, length.out=floor(palLength/2)))
  }
  
  # remove columns and rows below threshold
  W <- W[!apply(W,1,function(r) all(abs(r)<threshold)),]
  W <- W[,!apply(W,2,function(r) all(abs(r)<threshold))]

  # Plot heatmap
  pheatmap::pheatmap(t(W), color=color, breaks=breaks, fontsize=15, ...)
}



#' @title plotWeights: visualise the distribution of loadings for a certain factor in a given view
#' @name plotWeights
#' @description The first step to annotate factors is to visualise the corresponding feature loadings. \cr
#' This function shows all loadings for a given latent factor and view. . \cr
#' In contrast, the function \code{showTopWeights} zooms and displays the features with highest loading.
#' @param object a \code{\link{MOFAmodel}} object.
#' @param view name of view from which to get the corresponding weights
#' @param factor name of the factor
#' @param nfeatures number of features to label
#' @param abs take absolute value of the weights?
#' @param manual features to be manually labelled. A list of character vectors.
#' @param color_manual a character vector with colors, one for each element of 'manual'
#' @param scale boolean, scale all loadings from 0 to 1? 
#' @details the weights of the features within a view are relative to each other, they should not be interpreted in an absolute scale
#' @import ggplot2 ggrepel
#' @export
plotWeights <- function(object, view, factor, nfeatures=10, abs=FALSE, manual = NULL, color_manual = NULL, scale = TRUE) {
  
  # Sanity checks
  if (class(object) != "MOFAmodel") stop("'object' has to be an instance of MOFAmodel")
  stopifnot(all(view %in% viewNames(object)))  
  factor <- as.character(factor)
  stopifnot(factor %in% factorNames(object))
  if(!is.null(manual)) { stopifnot(class(manual)=="list"); stopifnot(all(Reduce(intersect,manual) %in% featureNames(object)[[view]]))  }
  
  # Collect expectations  
  # W <- getExpectations(object,"SW", as.data.frame = T)
  W <- getWeights(object,views=view, factors=factor, as.data.frame = T)
  W <- W[W$factor==factor & W$view==view,]
  
    # Scale values
  if(scale) W$value <- W$value/max(abs(W$value))
  
  # Parse the weights
  if (abs) W$value <- abs(W$value)
  
  # Filter the weights
  # if(nfeatures=="all") {
  #   nfeatures <- nrow(W)
  # } else {
  #   stopifnot(class(nfeatures)=="numeric")
  # }
  # W <- head(W[order(abs(W$value), decreasing=T),], n=nfeatures)
    
  # Define groups for labelling
  W$group <- "0"
  
  # Define group of features to color according to the loading
  if(nfeatures>0) W$group[abs(W$value) >= sort(abs(W$value), decreasing = T)[nfeatures]] <- "1"
  # if(!is.null(threshold)) W$group[abs(W$value) >= threshold] <- "1"
  
  # Define group of features to label manually
  if(!is.null(manual)) {
    if (is.null(color_manual)) {
      color_manual <- hcl(h = seq(15, 375, length = length(manual) + 1), l = 65, c = 100)[1:length(manual)]
    } else {
      stopifnot(length(color_manual)==length(manual)) 
    }
    for (m in 1:length(manual)) {
      W$group[W$feature %in% manual[[m]]] <- as.character(m+1)
    }
  }
  
  # Sort by weight 
  W <- W[order(W$value),]
  W$feature <- factor(W$feature, levels=W$feature)
  
  # Define plot title
  # if(is.null(main)) main <- paste("Distribution of weigths of LF", factor, "in", view, "view")
  
  # Generate plot
  W$tmp <- as.character(W$group!="0")
  gg_W <- ggplot(W, aes(x=feature, y=value, col=group)) + 
    # scale_y_continuous(expand = c(0.01,0.01)) + scale_x_discrete(expand = c(0.01,0.01)) +
    geom_point(aes(size=tmp)) + labs(x="Rank position", y="Loading") +
    scale_x_discrete(breaks = NULL, expand=c(0.05,0.05)) +
    ggrepel::geom_text_repel(data = W[W$group!="0",], aes(label = feature, col = group),
                             segment.alpha=0.1, segment.color="black", segment.size=0.3, box.padding = unit(0.5, "lines"), show.legend= F)
  # Define size
  gg_W <- gg_W + scale_size_manual(values=c(0.5,2)) + guides(size=F)
  
  # Define colors
  cols <- c("grey","black",color_manual)
  gg_W <- gg_W + scale_color_manual(values=cols) + guides(col=F)
  
  # Add Theme  
  gg_W <- gg_W +
    theme(
      # panel.spacing = margin(5,5,5,5),
      # panel.border = element_rect(colour = "black", fill=NA, size=0.75),
      plot.title = element_text(size=rel(1.3), hjust=0.5),
      # axis.title.x = element_blank(),
      axis.text.x = element_blank(),
      axis.text.y = element_text(size=rel(1.3), color="black"),
      axis.title.y = element_text(size=rel(1.5), color="black"),
      axis.ticks.x = element_blank(),

      # white background and dark border
      panel.background = element_rect(fill = "white", colour = NA),
      panel.border     = element_rect(fill = NA, colour = "grey20"),
      # make gridlines dark, same contrast with white as in theme_grey
      panel.grid.major = element_line(colour = "grey92"),
      panel.grid.minor = element_line(colour = "grey92", size = rel(0.5)),
      # contour strips to match panel contour
      strip.background = element_rect(fill = "grey85", colour = "grey20")
    )
  
  return(gg_W)
}



#' @title plotTopWeights: visualise the top weights for a certain factor and view
#' @name plotTopWeights
#' @description The first step to annotate factors is to visualise the corresponding feature loadings. \cr
#' This function zooms and displays the features with highest loading in a given latent factor and view. \cr
#' In contrast, the function \code{showAllWeights} displays the entire distribution of weights.
#' @param object a \code{\link{MOFAmodel}} object.
#' @param view character vector with the view name or numeric vector with the index of the view.
#' @param factor character vector with the factor name or numeric vector with the index of the factor.
#' @param nfeatures number of top features to display.
#' @param abs take absolute value of the weights? (default=TRUE)
#' @param sign can be 'positive', 'negative' or 'both' to show only positive, negative or all weigths, respectively
#' @param scale scales all loading by absolute value of maximal loading
#' @import ggplot2
#' @export
plotTopWeights <- function(object, view, factor, nfeatures = 5, abs = TRUE, scale = TRUE, sign = "both") {
  
  # Sanity checks
  if (class(object) != "MOFAmodel") stop("'object' has to be an instance of MOFAmodel")
  stopifnot(view %in% viewNames(object))
  # if(!is.null(manual_features)) { stopifnot(class(manual_features)=="list"); stopifnot(all(Reduce(intersect,manual_features) %in% featureNames(object)[[view]]))  }
  
  # Collect expectations  
  W <- getWeights(object, factors=factor, views=view, as.data.frame=T)

  # Scale values by loading with highest (absolute) value
  if(scale) W$value <- W$value/max(abs(W$value))

  # store sign
  W <- W[W$value!=0,]
  W$sign <- ifelse(W$value>0, "+", "-")

 # select subset of only positive or negative loadings
  if (sign=="positive") { W <- W[W$value>0,] } else if (sign=="negative") { W <- W[W$value<0,] }

   # Absolute value
  if (abs) W$value <- abs(W$value)

  
  # Extract relevant features
  W <- W[with(W, order(-abs(value))), ]
  if (nfeatures>0) features <- head(W$feature,nfeatures) # Extract top hits
  # if (!is.null(manual_features)) features <- W$feature[W$feature %in% manual_features] # Extract manual hits
  W <- W[W$feature %in% features,]
  
  # Sort according to loadings
  W <- W[with(W, order(-value, decreasing = T)), ]
  W$feature <- factor(W$feature, levels=W$feature)
  
  p <- ggplot(W, aes(x=feature, y=value)) +
    geom_point(size=2) +
    geom_segment(aes(xend=feature, yend=0), size=0.75) +
    scale_colour_gradient(low="grey", high="black") +
    # scale_colour_manual(values=c("#F8766D","#00BFC4")) +
    # guides(colour = guide_legend(title.position="top", title.hjust = 0.5)) +
    coord_flip() +
    theme(
      axis.title.x = element_text(size=rel(1.5), color='black'),
      axis.title.y = element_blank(),
      axis.text.y = element_text(size=rel(1.2), hjust=1, color='black'),
      axis.text.x = element_text(size=rel(1.5), color='black'),
      axis.ticks.y = element_blank(),
      axis.ticks.x = element_line(),
      legend.position='top',
      # legend.title=element_text(size=rel(1.5), color="black"),
      legend.title=element_blank(),
      legend.text=element_text(size=rel(1.3), color="black"),
      legend.key=element_rect(fill='transparent'),
      panel.background = element_blank(),
      aspect.ratio = .7
      )
  
  if (sign=="negative") p <- p + scale_x_discrete(position = "top")

  # If absolute values are used, add the corresponding signs to the plot
  if (abs) p <- p +  ylim(0,max(W$value)+0.1)+ geom_text(label=W$sign,y=max(W$value)+0.1, size=10)

  if(abs & scale) p <-  p + ylab(paste("Absolute loading on factor", factor))  
  else if(abs & !scale) p <- p + ylab(paste("Absolute loading on factor", factor))
  else if(!abs & scale) p <- p + ylab(paste("Loading on factor", factor))
  else p <- p + ylab(paste("Loading on factor", factor))
  return(p)
  
}
