.predict.phi <- function(ts, model, family, varcov=TRUE){

  # Get coefficients of model
  # and the link function
  if(class(model) == "geese"){
    coefs <- matrix(model$beta)
    varcor <- model$vbeta
  } else {
    coefs <- matrix(coef(model))
    varcor <- vcov(model)
  }

  # Get a data frame of t's so that
  # we can get the model matrix
  # ri won't actually be used, just a placeholder so the formula works
  temp.dat <- data.frame(
    ri=1,
    ui=ts
  )
  ts.pred <- model.matrix(model$formula, data=temp.dat)

  # Get the linear predictor
  lin_predictor <- ts.pred %*% coefs

  # Transform the linear predictor
  phi <- family$linkinv(lin_predictor)

  if(varcov){

    # We have by delta method Var(T \beta) = T %*% Var(\beta) %*% T^t
    # Also by delta method, Var(linkinv(T \beta)) = J %*% T %*% Var(\beta) %*% T^t J
    # where J is the gradient of the linkinv() transformation.

    # For efficiency's sake, we can instead first calculate J %*% T
    # since (J %*% T)^t = T^t %*% J^t = T^t %*% J
    # and then calculate the Cholesky decomposition of Var(\beta) so that we
    # can write Var(\beta) = U^t U where U is the upper triangular
    # matrix from the decomposition (what chol function returns).

    # Then we have, with R = J %*% T %*% U^t,
    # the final variance-covariance matrix is R %*% R^t.

    # 1. Var(\beta) and Cholesky decomposition
    U <- chol(varcor)

    # 2. Derivative of transformation
    delta_g <- family$mu.eta(lin_predictor)
    J <- diag(c(delta_g))

    # 3. Calculate R matrix
    R <- J %*% ts.pred %*% t(U)

    # 4. Calculate final variance
    phi_var <- R %*% t(R)
  } else {
    phi_var <- NULL
  }

  return(list(point=phi, var=phi_var))
}

#' Create a phi matrix of d x d based on draws from the phi.hat function
#'
#' @param model A model object (either glm or gee)
#' @param ts_index Ts that should be used to form the matrix
#' @import data.table
.matrix.phi <- function(model, family, ts, ts_index){

  res <- .predict.phi(ts=ts, model=model, family=family)
  phi <- res[["point"]]
  phi_var <- res[["var"]]

  # For when log UI is used
  if(!0 %in% ts_index){
    ts_index <- c(0, ts_index)
    ts <- c(0, ts)
    phi <- rbind(phi[1,], phi)
    phi_var <- rbind(phi_var[1,], phi_var)
    phi_var <- cbind(phi_var[,1], phi_var)

    # For phi functions, enforce that they have probability 1 at time 0
    # which also means covariance 0 with all other time points
    phi[1] <- 1
    phi_var[1, ] <- 0
    phi_var[, 1] <- 0
  }

  dt <- diff(ts)[1]

  if(sum((phi > 1) | (phi < 0)) > 0) stop("cannot have predicted probabilities
                                          outside of 0-1 for the phi func")

  # Calculate cumulative phi and convert to a data frame
  cphi <- cumsum(phi * dt)
  cphi_d <- data.table(
    index=ts_index,
    phi=cphi
  )

  # Calculate the 2-d integral of the variance-covariance matrix
  # at all grid points by using cumsum on the rows and columns.
  csum <- t(apply(apply(phi_var * dt^2, 2, cumsum), 1, cumsum))

  # Reshape the matrix into a data frame so that it's easier to work with
  # and merge onto the id grid.
  csum <- data.table(csum)
  # Need to subtract one because the indexing starts at 0
  csum <- csum[, indexX := .I-1]
  csum_d <- melt.data.table(csum, id.vars="indexX")

  ts_index <- data.table(
    ts=ts,
    index=ts_index
  )
  ts_index[, row := .I]

  csum_d <- csum_d[, variable := as.numeric(gsub("V", "", variable))]
  csum_d <- merge(csum_d, ts_index[, .(row, index)], by.x="variable", by.y="row")
  setnames(csum_d, c("index", "value"), c("indexY", "rho"))
  csum_d <- csum_d[, .(indexX, indexY, rho)]

  return(list(cphi=cphi_d, csum=csum_d, ts_index=ts_index))
}
