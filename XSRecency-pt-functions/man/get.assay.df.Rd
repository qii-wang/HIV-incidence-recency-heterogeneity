% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get-rita-data.R
\name{get.assay.df}
\alias{get.assay.df}
\title{Get external data frame using CEPHIA data for a given recency
algorithm specified by the user.}
\usage{
get.assay.df(assays, algorithm, subtype = NULL, ever_art = NULL)
}
\arguments{
\item{assays}{A vector of assays to include}

\item{algorithm}{A function that defines the recency indicator
with arguments in the same order as the `assays` vector.
Arguments do not need to have the same name as `assays`.
E.g., if you have `assays = c("BED", "viral_load")`,
you can have `algorithm = function(b, v) ...` where `b`
indicates BED and `v` indicates viral load.}

\item{subtype}{HIV subtypes to include (one of "A1", "B", "C", "D").
By default includes everyone.}

\item{ever_art}{Subset data to only those who have used ARTs or
have not. By default includes everyone.}
}
\description{
Get external data frame using CEPHIA data for a given recency
algorithm specified by the user.
}
\examples{
f <- function(b, l, v){
  ifelse((b > 1 & l < 3 & !is.na(v)), 1, 0)
}
get.assay.df(assays=c("BED", "LAg-Sedia", "viral_load"),
             algorithm=f)

f <- function(l, v){
  v <- ifelse(l > 1.5, 0, v)
  return(
    ifelse((l <= 1.5) & (v > 1000), 1, 0)
  )
}
test <- get.assay.df(assays=c("LAg-Sedia", "viral_load"), algorithm=f)
}
