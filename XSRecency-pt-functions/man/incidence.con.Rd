% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/data-generator-old.R, R/data-generator.R
\name{incidence.con}
\alias{incidence.con}
\title{Constant incidence function}
\usage{
incidence.con(t, lambda_0, rho = NA)

incidence.con(t, lambda_0, rho = NA)
}
\arguments{
\item{t}{Time, float or vector}

\item{lambda_0}{Incidence constant value}
}
\value{
Incidence at time t

Incidence at time t
}
\description{
Constant incidence function

Constant incidence function
}
\examples{
incidence.con(0, lambda_0=0.05)
incidence.con(c(-1, 0, 0), lambda_0=0.05)
incidence.con(0, lambda_0=0.05)
incidence.con(c(-1, 0, 0), lambda_0=0.05)
}
