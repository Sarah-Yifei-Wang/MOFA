% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plotData.R
\name{plotDataHeatmap}
\alias{plotDataHeatmap}
\title{plotDataHeatmap: plot data heatmap of relevant features}
\usage{
plotDataHeatmap(object, view, factor, features = 50, includeWeights = FALSE,
  transpose = FALSE, imputed = FALSE, ...)
}
\arguments{
\item{object}{a \code{\link{MOFAmodel}} object.}

\item{view}{character vector with the view name, or numeric vector with the index of the view.}

\item{factor}{character vector with the factor name, or numeric vector with the index of the factor.}

\item{features}{if an integer, the total number of features to plot, based on the absolute value of the loading. Default is 50
If a character vector, a set of manually-defined features.}

\item{includeWeights}{boolean indicating whether to include the weight of each feature as an extra annotation in the heatmap. Default is FALSE.}

\item{transpose}{boolean indicating whether to transpose the output heatmap. Default is FALSE, which corresponds to features as rows and samples as columns.}

\item{imputed}{boolean indicating whether to use the imputed data instead of the original data. Default is FALSE.}

\item{...}{further arguments that can be passed to \link[pheatmap]{pheatmap} [pheatmap::pheatmap]}
}
\description{
Function to plot a heatmap of the input data for relevant features, usually the ones with highest loadings in a given factor.
}
\details{
One of the first steps for the annotation of a given factor is to visualise the corresponding loadings using for example \code{\link{plotWeights}} or \code{\link{plotTopWeights}}.
These methods show you which features are driving the heterogeneity. However, weights are a rather abstract measurements and one might also be interested in visualising the heterogeneity directly in the original data. This what the function \code{\link{plotDataHeatmap}} does.
In particular, this method plots a heatmap for selected features (by default the top ones with highest loading). This should reveal the underlying pattern that is captured by the latent factor. \cr
A similar function for doing scatterplots rather than heatmaps is \code{\link{plotDataScatter}}.
}
\examples{
# Load example of MOFA model
model <- loadModel(system.file("extdata", "model15.hdf5", package = "MOFAtools"))

# Plot top 50 features for factor 1 in the mRNA view
plotDataHeatmap(model, "mRNA", 1, 50)

# Plot top 50 features for factor 1 in the mRNA view, do not show feature or row names
plotDataHeatmap(model, "mRNA", 1, 50, show_colnames = FALSE, show_rownames = FALSE) 
}
