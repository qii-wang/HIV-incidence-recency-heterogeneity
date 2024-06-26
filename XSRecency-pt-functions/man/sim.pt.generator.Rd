% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/data-generator.R
\name{sim.pt.generator}
\alias{sim.pt.generator}
\title{Generates prior testing data for positive subjects
based on a prior testing distribution and prior testing probability}
\usage{
sim.pt.generator(ptest.dist, ptest.prob, ptest.dist2 = NULL)
}
\arguments{
\item{ptest.dist}{A prior test result distribution function, which must have
be a function of `u` which is an
infection duration
though it can ignore the `u` argument inside the function.
An example is `rnorm(1, mean=u)`.}

\item{ptest.prob}{Probability of prior test result being available.
Can instead be a function of `u`, the infection duration.}
}
\description{
Generates prior testing data for positive subjects
based on a prior testing distribution and prior testing probability
}
\examples{
e.func <- function(e) infections.lin(e, t=0, p=0.29, lambda=0.032, rho=0.07)
params <- get.gamma.params(window=200/365.25, shadow=191/365.25)
phi.func <- function(t) 1-pgamma(t, shape = params[1], rate = params[2])
sim <- sim.screening.generator(prevalence=0.29, e.func=e.func, phi.func=phi.func)
df <- sim(100)
sim.pt <- sim.pt.generator(ptest.dist=function(u) runif(1, 0, 4),
                         ptest.prob=function(u) 0.5)
sim.pt(df[df$di == 1,])

}
