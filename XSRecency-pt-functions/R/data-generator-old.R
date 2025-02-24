
library(magrittr)

#' Generates raw data of number positive, negative, and screened
#' based on study parameters
#' that can be used later to simulate infection times.
#'
#' @param n_sims Number of simulations
#' @param n Number of observations per time point
#' @param prevalence Constant prevalence
#' @param times Times at which enrollment happens
generate.raw.data <- function(n_sims, n, prevalence, times=c(0)){
  # number of times
  n_times <- length(times)

  # number of positive subjects
  n_p <- replicate(n_times, rbinom(n=n_sims, size=n, prob=prevalence)) %>% t

  # number of negative subjects
  n_n <- n - n_p

  return(list(
    n=matrix(n, nrow=n_times, ncol=n_sims),
    n_p=n_p,
    n_n=n_n,
    times=matrix(rep(times, n_sims), ncol=n_sims, byrow=FALSE)
  ))
}

#' Simulate recency indicators based on the data, true phi function,
#' and the infection incidence function.
#'
#' Also possibly simulate prior test results.
#'
#' @param sim_data Outputs from the `generate.raw.data` function
#' @param infection.function Function that simulates the infection time
#' @param phi.func Test positive function for recency assay
#' @param baseline_incidence Baseline incidence value (time 0)
#' @param prevalence Constant prevalence value
#' @param rho A parameter to the `infection.function` for how quickly incidence changes
#' @param incidence.function An incidence function in place of `infection.function`.
#'   Cannot pass both arguments.
#' @param ptest.dist A prior test result distribution function.
#' @param ptest.prob Probability of prior test result being available.
#' @param ... Additional arguments to the `simulate.infection.times` function if you're
#'   passing an `incidence.function` instead of an `infection.function`.
#' @importFrom data.table data.table
#' @import magrittr
#'
#' @examples
#' dat <- generate.raw.data(n_sims=10, n=100, prevalence=0.5, times=c(0, 0))
#' sim <- simulate.recent(sim_data=dat, infection.function=infections.con,
#'                        baseline_incidence=0.05, prevalence=0.5, rho=NA,
#'                        phi.func=function(t) 1 - pgamma(t, 1, 2),
#'                        times=c(0, 1), summarize=FALSE,
#'                        ptest.dist=function(n) runif(n, 0.0, 5.0),
#'                        ptest.prob=0.5, bigT=2)
#' sim <- simulate.recent(sim_data=dat, infection.function=infections.con,
#'                        baseline_incidence=0.05, prevalence=0.5, rho=NA,
#'                        phi.func=function(t) 1 - pgamma(t, 1, 2),
#'                        times=c(0, 1), summarize=TRUE,
#'                        ptest.dist=function(n) runif(n, 0.0, 5.0),
#'                        ptest.prob=0.5, bigT=2)
#' dat <- generate.raw.data(n_sims=10, n=100, prevalence=0.5, times=c(0))
#' sim <- simulate.recent(sim_data=dat, infection.function=infections.con,
#'                        baseline_incidence=0.05, prevalence=0.5, rho=NA,
#'                        phi.func=function(t) 1 - pgamma(t, 1, 2),
#'                        summarize=TRUE,
#'                        ptest.dist=function(n) runif(n, 0.0, 5.0),
#'                        ptest.prob=0.5, bigT=2)
simulate.recent <- function(sim_data, infection.function=NULL,
                            phi.func, baseline_incidence, prevalence, rho, summarize=TRUE,
                            incidence.function=NULL,
                            ptest.dist=NULL, ptest.prob=0.0,
                            bigT=NULL,
                            ...){

  if(is.null(incidence.function) & is.null(infection.function)){
    stop("Pass either an incidence or infection function.")
  } else if(!is.null(incidence.function) & !is.null(infection.function)){
    stop("Pass either an incidence or infection function, but not both.")
  }

  # Get dimensions
  dims <- dim(sim_data$n_p)
  n_times <- dims[1]
  n_sims <- dims[2]

  # Convert the matrices to vectors
  # The data are ordered by simulation first, then times
  times <- as.vector(sim_data$times)
  n_p <- as.vector(sim_data$n_p)
  n_n <- as.vector(sim_data$n_n)

  # infection time
  if(!is.null(infection.function)){
    # get the uniform for the cumulative distribution
    # function for each individual
    cdfs <- lapply(n_p, runif)
    t_infect <- mapply(infection.function, e=cdfs, t=times, p=prevalence,
                       lambda_0=baseline_incidence, rho=rho, SIMPLIFY=F)
  } else {
    t_infect <- sim.infection.times(p=prevalence,
                                    inc.function=incidence.function,
                                    ...)
  }

  # infection duration to pass to the phi hat function
  infect_duration <- mapply(function(t, u) t - u, t=times, u=t_infect, SIMPLIFY=F)

  # if there is a recent test positive function provided,
  # get the indicator of recent infection
  if(!is.null(phi.func)){
    # probability of recent infection
    recent_probabilities <- lapply(infect_duration, phi.func)
    # indicators
    indicators <- lapply(recent_probabilities,
                         function(x) rbinom(n=length(x), size=1, prob=x))
  }

  if(!is.null(ptest.dist)){
    # Get the prior testing times for everyone
    test_times <- mapply(function(t, n) t - ptest.dist(n), t=times, n=n_p)
    # Simulate whether or not those tests are available (were actually taken)
    available <- lapply(n_p, function(n) rbinom(n=n, size=1, prob=ptest.prob))
    # Generate vector with prior time or NA if not available
    ptest_times <- mapply(function(t, a) ifelse(a, t, 0), t=test_times, a=available)
    # See whether or not the test was positive
    ptest_delta <- mapply(function(it, pt) as.integer(it < pt), pt=ptest_times, it=t_infect)

    # Define a function for getting the new recency indicator
    # if there are prior test results.
    enhanced.r <- function(ti, ri, di){
      ri_star <- (di == 0) & (-ti <= bigT)
      ri_tild <- 1 - ((-ti > bigT) & (di == 1))
      ri_new <- (ri | ri_star) & ri_tild
      return(ri_new)
    }

    integrate.tinan <- function(ti) ifelse(is.na(ti), NA, integrate(phi.func, 0, ti)$value)
    integrate.ti <- function(ti) sapply(ti, function(t) integrate.tinan(t))

    ri_new <- mapply(FUN=enhanced.r, ti=ptest_times, ri=indicators, di=ptest_delta)
    recent_ti <- lapply(ptest_times, function(x) -x <= bigT)
    int_phi_ti <- lapply(ptest_times, function(x) -x - integrate.ti(-x))
    recent_int_ti <- mapply(FUN=function(x, y) x * y, x=recent_ti, y=int_phi_ti)
    int_phi_ti_ti <- mapply(FUN=function(x, y) (1-x) * -y, x=recent_ti, y=ptest_times)
  }

  if(summarize == TRUE){
    # number of recents
    n_r <- lapply(indicators, sum) %>% unlist

    # Additional info from prior test results
    if(!is.null(ptest.dist)){
      # This is N^*_{rec}
      n_r_pt <- lapply(ri_new, sum) %>% unlist
      # This is \sum I(T_i \leq T^*)
      num_beta <- lapply(recent_ti, sum) %>% unlist
      # This is \sum I(T_i \leq T^*) * int_0^{T_i} (1 - \phi(u)) du
      den_omega <- lapply(recent_int_ti, sum) %>% unlist
      # This is I(T_i > T^*) * T_i
      den_beta <- lapply(int_phi_ti_ti, sum) %>% unlist
    } else {
      n_r_pt <- NULL
      num_beta <- NULL
      den_omega <- NULL
      den_beta <- NULL
    }

    if(n_times > 1){
      # if we have multiple times, convert it back into a matrix
      n_r       <- matrix(n_r, nrow=n_times, ncol=n_sims, byrow=FALSE)
      n_r_pt    <- matrix(n_r_pt, nrow=n_times, ncol=n_sims, byrow=FALSE)
      num_beta  <- matrix(num_beta, nrow=n_times, ncol=n_sims, byrow=FALSE)
      den_omega <- matrix(den_omega, nrow=n_times, ncol=n_sims, byrow=FALSE)
      den_beta  <- matrix(den_beta, nrow=n_times, ncol=n_sims, byrow=FALSE)
      n_p       <- sim_data$n_p
      n_n       <- sim_data$n_n
      times     <- sim_data$times
      n         <- sim_data$n
    } else {
      # if we have only one time (cross-sectional), keep everything
      # in vector form
      n_p   <- as.vector(sim_data$n_p)
      n_n   <- as.vector(sim_data$n_n)
      n     <- as.vector(sim_data$n)
      times <- as.vector(sim_data$times)
    }

    aspect_list <- list(
      n=n,
      n_p=n_p,
      n_n=n_n,
      n_r=n_r,
      times=times,
      n_r_pt=n_r_pt,
      num_beta=num_beta,
      den_omega=den_omega,
      den_beta=den_beta
    )
    return(aspect_list)
  } else {

    # Get the simulation number
    sim <- rep(1:n_sims, each=n_times)

    # Get the enrollment times for negative and positive
    time_neg <- rep(times, n_n)
    time_pos <- rep(times, n_p)
    time <- c(time_neg, time_pos)

    # Get simulation number for each negative and positive
    sim_neg <- rep(sim, n_n)
    sim_pos <- rep(sim, n_p)
    sim <- c(sim_neg, sim_pos)

    # Get prevalence positive indicator
    prev_pos <- rep(1, length(sim_pos))
    prev_neg <- rep(0, length(sim_neg))
    prev <- c(prev_neg, prev_pos)

    # Infection time and prior testing time / result
    na_neg <- rep(NA, length(time_neg))
    infect <- c(na_neg, unlist(t_infect))

    if(!is.null(ptest.dist)){
      priorT <- c(na_neg, unlist(ptest_times))
      priorD <- c(na_neg, as.integer(unlist(ptest_delta)))
    } else {
      priorT <- NULL
      priorD <- NULL
    }
    df <- data.table(
      sim=sim,
      time=time,
      pos=prev,
      itime=infect,
      priorT=priorT,
      priorD=priorD
    )

    if(!is.null(phi.func)){

      # Phi function evaluated at the infection times *-1
      probs_pos <- unlist(recent_probabilities)
      probs_neg <- rep(NA, length(time_neg))
      probs <- c(probs_neg, probs_pos)

      # Whether or not they tested positive
      r_pos <- unlist(indicators)
      r_neg <- rep(NA, length(time_neg))
      r <- c(r_neg, r_pos)

      df$probs <- probs
      df$rpos <- r
    }
    setorder(df, sim, time, pos, itime)
    return(df)
  }
}

#' Create simulations of trials based on a past infection time function
#' and a prevalence and baseline incidence (time 0).
#'
#' @export
#' @param n_sims Number of simulations
#' @param n Number of subjects screened
#' @param infection.function Function that simulates the infection time
#' @param phi.func Optional test positive function for recency assay.
#'   If you pass \code{summarize=TRUE}, then you must provide a test positive function.
#' @param baseline_incidence Baseline incidence value (time 0)
#' @param prevalence Constant prevalence value
#' @param rho A parameter to the \code{infection.function} for how quickly incidence changes
#' @param times A vector of times at which to enroll (e.g. c(0, 1, 2, 3))
#' @param summarize Whether to return a summary of the dataset or unit-record data
#' @return If \code{summarize=TRUE}, a list of vectors (or matrices if
#'   length(times > 1) for summary screening quantities
#'   across simulations (and potentially times if length(times) > 1):
#'   \itemize{
#'     \item n: number screened
#'     \item times: times screened
#'     \item n_p: number of positives
#'     \item n_n: number of negatives
#'     \item n_r: number of recents
#'   }
#'   If \code{summarize=FALSE}, then returns a list of data frames by simulation
#'   that have unit-record data with infection times with column names:
#'   \itemize{
#'     \item time: time screened
#'     \item pos: indicator for positive
#'     \item itime: infection time (reference time 0)
#'     \item probs: recency test positive probability based on infection time
#'     \item rpos: indicator for recency test positive, if a phi function is passed
#'   }
#' @examples
#' set.seed(1)
#' generate.data(n_sims=3, n=2, infection.function=infections.con,
#'               baseline_incidence=0.05, prevalence=0.5, rho=NA,
#'               phi.func=function(t) 1 - pgamma(t, 1, 2),
#'               times=c(0, 1), summarize=FALSE)
#' generate.data(n_sims=3, n=100, infection.function=infections.con,
#'               baseline_incidence=0.05, prevalence=0.3, rho=NA,
#'               phi.func=function(t) 1 - pgamma(t, 1, 2),
#'               times=c(0, 1), summarize=TRUE)
#' generate.data(n_sims=3, n=100, infection.function=infections.con,
#'               baseline_incidence=0.05, prevalence=0.3, rho=NA,
#'               phi.func=function(t) 1 - pgamma(t, 1, 2),
#'               times=c(0), summarize=TRUE)
generate.data <- function(n_sims, n, infection.function,
                          baseline_incidence,
                          prevalence, rho, phi.func=NULL, times=c(0), summarize=TRUE){

  # TODO: include some sanity checks
  if(summarize & is.null(phi.func)) stop("Need a phi function
                                       to summarize recents.")

  data <- generate.raw.data(n_sims, n, prevalence, times=times)
  data <- simulate.recent(data, infection.function, phi.func,
                          baseline_incidence, prevalence, rho, summarize=summarize)
  return(data)
}

# INFECTION FUNCTIONS

#' Constant incidence function
#'
#' @param t Time, float or vector
#' @param lambda_0 Incidence constant value
#' @return Incidence at time t
#' @examples
#' incidence.con(0, lambda_0=0.05)
#' incidence.con(c(-1, 0, 0), lambda_0=0.05)
incidence.con <- Vectorize(function(t, lambda_0, rho=NA) lambda_0)

#' Linearly decreasing incidence function
#'
#' \deqn{
#'   \lambda(t) = \lambda_0 - \rho t
#' }
#'
#' @param t Time, float or vector
#' @param lambda_0 Incidence at time 0
#' @param rho Linear decrease in incidence
#' @return Incidence at time t
#' @examples
#' incidence.lin(0, lambda_0=0.05, rho=1e-3)
#' incidence.lin(c(-1, 0, 1), lambda_0=0.05, rho=1e-3)
incidence.lin <- function(t, lambda_0, rho=1) lambda_0 - rho * t

#' Exponentially decreasing incidence function
#'
#' \deqn{
#'   \lambda(t) = \lambda_0 \exp(-\rho t)
#' }
#'
#' @param t Time, float or vector
#' @param lambda_0 Incidence at time 0
#' @param rho Exponential decrease in incidence
#' @return Incidence at time t
#' @examples
#' incidence.exp(0, lambda_0=0.05, rho=0.07)
#' incidence.exp(c(-1, 0, 1), lambda_0=0.05, rho=0.07)
incidence.exp <- function(t, lambda_0, rho=1) lambda_0 * exp(-rho * t)

#' Infection times function based on constant incidence.
#'
#' @param e A number between 0 and 1 (randomly generated), float or vector
#' @param t Time, float
#' @param p Constant prevalence
#' @param lambda_0 Baseline incidence
#' @return Infection time
#' @examples
#' e <- runif(10)
#' infections.con(e, t=0, p=0.2, lambda_0=0.05)
infections.con <- function(e, t, p, lambda_0, rho=NA){
  # Note that you can work with e or 1 - e since e is Uniform(0, 1)
  infections <- t - p*e / ((1 - p) * lambda_0)
  return(infections)
}

#' Infection times function based on linearly decreasing incidence.
#'
#' @param e A number between 0 and 1 (randomly generated), float or vector
#' @param t Time, float
#' @param p Constant prevalence
#' @param lambda_0 Baseline incidence
#' @param rho Linearly decreasing incidence parameter
#' @return Infection time
#' @examples
#' e <- runif(10)
#' infections.lin(e, t=0, p=0.2, lambda_0=0.05, rho=1e-3)
infections.lin <- function(e, t, p, lambda_0, rho){
  incidence <- lambda_0
  numerator <- incidence**2 + 2 * rho * p * e / (1 - p)
  numerator <- sqrt(numerator) - incidence

  infections <- t - numerator / rho
  return(infections)
}

#' Infection times function based on exponential decreasing incidence.
#'
#' @param e A number between 0 and 1 (randomly generated), float or vector
#' @param t Time, float
#' @param p Constant prevalence
#' @param lambda_0 Baseline incidence
#' @param rho Linearly decreasing incidence parameter
#' @return Infection time
#' @examples
#' e <- runif(10)
#' infections.exp(e, t=0, p=0.2, lambda_0=0.05, rho=0.07)
infections.exp <- function(e, t, p, lambda_0, rho){
  incidence <- lambda_0
  infections <- t - (1/rho) * log(rho*p*e/((1-p)*incidence) + 1)
  return(infections)
}

# INFECTION FUNCTION FOR ARBITRARY INCIDENCE FUNCTION

#' Function to simulate infection times from an arbitrary incidence
#' function and with constant prevalence.
#'
#' @export
#' @param p Constant prevalence value
#' @param inc.function A function of time that returns incidence
#' @param nsims Number of infection times to simulate
#' @param dt The precision for numerical integration. May need to increase.
#' @return A vector of infection durations
#' @examples
#' set.seed(1)
#' sim.infection.times(p=0.2, nsims=15,
#'                     inc.function=function(t) incidence.con(t, 0.5))
#' sim.infection.times(p=0.2, nsims=15,
#'                     inc.function=function(t) incidence.con(t, 0.05))
sim.infection.times <- function(p, inc.function, nsims=1000, dt=0.001){
  # TODO: Change this to infection duration in the generate.data function
  # Need to vectorize a scalar function
  if(length(inc.function(c(1, 2))) == 1) inc.function <- Vectorize(inc.function)

  # Simulate e's and the solve for T
  e <- runif(nsims)
  lh <- e * p/(1-p)
  ds <- seq(0, 100, by=dt)
  vals <- inc.function(ds) # TODO: Shift lambda for longitudinal
  int <- cumsum(vals*dt)
  if(min(lh) < min(int)) stop("Pick a larger dt for the integration")
  indexes <- sapply(lh, function(x) max(which(int < x)))
  times <- ds[indexes]
  return(times)
}
