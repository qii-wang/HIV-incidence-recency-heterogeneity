context("External study simulation")

test_that("External study simulation", {
  set.seed(200)
  func <- function(t) 1 - pgamma(t, 1, 2)
  phi <- assay.properties.nsim(1, func, bigT=2, tau=12, last_point=FALSE)
  expect_equal(phi$mu_est, 0.4490537, tolerance=1e-6)
  expect_equal(phi$mu_var, 0.0003872699, tolerance=1e-6)
  expect_equal(phi$omega_est, 0.4404954, tolerance=1e-6)
  expect_equal(phi$omega_var, 0.0003406153, tolerance=1e-6)
  expect_equal(phi$beta_est, 0.0006666667, tolerance=1e-6)
  expect_equal(phi$beta_var, 4.441481e-07, tolerance=1e-6)
})

