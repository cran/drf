% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mmdVariableImportance.R
\name{variableImportance}
\alias{variableImportance}
\title{Variable importance based on MMD}
\usage{
variableImportance(
  object,
  h = NULL,
  response.scaling = TRUE,
  type = "difference"
)
}
\arguments{
\item{object}{an S3 object of class drf.}

\item{h}{the bandwidth parameter, default to NULL using then the median heuristic.}

\item{response.scaling}{a boolean value indicating if the responses should be scaled globally beforehand.}

\item{type}{the type of importance, could be either "raw", the plain MMD values, "relative", the ratios to the observed MMD or "difference", the excess to the observed MMD}
}
\value{
a vector of variable importance values.
}
\description{
compute an mmd-based variable importance for the drf fit.
}
