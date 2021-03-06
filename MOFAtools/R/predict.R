
######################################
## Functions to perform predictions ##
######################################

#' @title Do predictions using a fitted MOFA model
#' @name predict
#' @description This function uses the latent factors and the weights to do predictions in the input data
#' @param object a \code{\link{MOFAmodel}} object.
#' @param views character vector with the view name(s), or numeric vector with the view index(es), default is "all".
#' @param factors character vector with the factor name(s) or numeric vector with the factor index(es), default is "all".
#' @param type type of prediction returned. "response" gives mean for gaussian and poisson, and probabilities for bernoulli , 
#' "link" gives the linear predictions, "inRange" rounds the fitted values from "terms" for integer-valued distributions to the next integer. Default is "inRange".
#' @details the denoised and condensed low-dimensional representation of the data captures the main sources of heterogeneity of the data. 
#' These representation can be used to do predictions using the equation Y = WX. This is the key step underlying imputation, see \code{\link{imputeMissing}} and Methods section of the article.
#' @return List with data predictions, each element corresponding to a view.
#' @export

predict <- function(object, views = "all", factors = "all", type = c("inRange","response", "link")){

  # Sanity checks
  if (class(object) != "MOFAmodel") stop("'object' has to be an instance of MOFAmodel")
  
  # Get views  
  if (paste0(views,sep="",collapse="") =="all") { 
    views = viewNames(object)
  } else {
    stopifnot(all(views%in%viewNames(object)))
  }
  
  # Get factors
  if (factors=="all") {
    factors = factorNames(object)
  } else {
    stopifnot(all(factors%in%factorNames(object)))
    factors <- c("intercept", factors)
  } 
  
  # Get type of predictions wanted 
  type = match.arg(type)
  
  # Collect weights
  W <- getWeights(object, views="all", factors=factors)

  # Collect factors
  Z <- getFactors(object)[,factors]
  Z[is.na(Z)] <- 0 # set missing values in Z to 0 to exclude from imputations
 
  # Predict data based on MOFA model
  predictedData <- lapply(sapply(views, grep, viewNames(object)), function(viewidx){
    
    # calculate terms based on linear model
    predictedView <- t(Z%*% t(W[[viewidx]])) 
    
    # make predicitons based on underlying likelihood
    if(type!="link"){
    lk <- object@ModelOpts$likelihood[viewidx]
    if(lk == "gaussian") predictedView <- predictedView
      else if (lk == "bernoulli") {predictedView <- (exp(predictedView)/(1+exp(predictedView))); if(type=="inRange") predictedView <- round(predictedView)}
        else if (lk == "poisson") {predictedView <- (exp(predictedView)); if(type=="inRange") predictedView <- round(predictedView)}
          else stop("Liklihood not implemented for imputation")
    }
    predictedView
  })

  names(predictedData) <- views

  return(predictedData)
}