# Generic for fitting the logistic (binomial family) GLM model
h2ofit <- function(fit, ...) UseMethod("h2ofit")

# S3 method for fitting h2o GLM with binomial() family (logistic regression):
h2ofit.h2oGLM <- function(fit, subsetH2Oframe, outvar, predvars, rows_subset, ...) {
  if (gvars$verbose) print("calling h2o.glm...")
  model.fit <- h2o::h2o.glm(x = predvars,
                            y = outvar,
                            intercept = TRUE,
                            training_frame = subsetH2Oframe,
                            family = "binomial",
                            standardize = TRUE,
                            solver = c("L_BFGS"),
                            lambda = 0L,
                            # solver = c("IRLSM"),
                            # remove_collinear_columns = TRUE,
                            max_iterations = 50,
                            ignore_const_cols = FALSE,
                            missing_values_handling = "Skip")

  # assign the fitted coefficients in correct order (same as predictor order in predvars)
  out_coef <- vector(mode = "numeric", length = length(predvars)+1)
  out_coef[] <- NA
  names(out_coef) <- c("Intercept", predvars)
  out_coef[names(model.fit@model$coefficients)] <- model.fit@model$coefficients
  fit$coef <- out_coef;
  fit$linkfun <- "logit_linkinv";

  fit$fitfunname <- "h2o.glm";
  confusionMat <- h2o::h2o.confusionMatrix(model.fit)
  fit$nobs <- confusionMat[["0"]][3]+confusionMat[["1"]][3]; # fit$nobs <- length(rows_subset);
  fit$H2O.model.object <- model.fit

  if (gvars$verbose) {
    print("h2oglm fits:")
    print(fit$coef)
  }

  # class(fit) <- c(class(fit)[1], c("glmfit"))
  class(fit) <- c(class(fit)[1], c("h2ofit"))
  return(fit)
}

# S3 method for h2o RFs fit (Random Forest):
h2ofit.h2oRF <- function(fit, subsetH2Oframe, outvar, predvars, rows_subset, ...) {
  if (gvars$verbose) print("calling h2o.randomForest...")
  model.fit <- h2o::h2o.randomForest(x = predvars,
                                     y = outvar,
                                     training_frame = subsetH2Oframe,
                                     ntree = 100,
                                     balance_classes = TRUE,
                                     ignore_const_cols = FALSE)

  fit$coef <- NULL;
  fit$fitfunname <- "h2o.randomForest";
  # fit$nobs <- length(rows_subset);
  confusionMat <- h2o::h2o.confusionMatrix(model.fit)
  fit$nobs <- confusionMat[["0"]][3]+confusionMat[["1"]][3]; # fit$nobs <- length(rows_subset);
  fit$H2O.model.object <- model.fit

  class(fit) <- c(class(fit)[1], c("h2ofit"))
  return(fit)
}

# S3 method for h2o GBM fit, takes BinDat data object:
h2ofit.h2oGBM <- function(fit, subsetH2Oframe, outvar, predvars, rows_subset, ...) {
  if (gvars$verbose) print("calling h2o.gbm...")
  model.fit <- h2o::h2o.gbm(x = predvars,
                            y = outvar,
                            training_frame = subsetH2Oframe,
                            distribution = "bernoulli",
                            ntrees = 100,
                            balance_classes = TRUE,
                            ignore_const_cols = FALSE)

  fit$coef <- NULL;
  fit$fitfunname <- "h2o.gbm";
  # fit$nobs <- length(rows_subset);
  confusionMat <- h2o::h2o.confusionMatrix(model.fit)
  fit$nobs <- confusionMat[["0"]][3]+confusionMat[["1"]][3]; # fit$nobs <- length(rows_subset);
  fit$H2O.model.object <- model.fit

  class(fit) <- c(class(fit)[1], c("h2ofit"))
  return(fit)
}

h2ofit.h2oSL <- function(fit, subsetH2Oframe, outvar, predvars, subset_idx, ...) {
  # ...
  # ... SuperLearner TO BE IMPLEMENTED ...
}

# IMPLEMENTING NEW CLASS FOR BINARY REGRESSION THAT USES h2o
# NEEDS TO be able to pass on THE REGRESSION SETTINGS FOR h2o-specific functions
BinomialH2O  <- R6Class(classname = "BinomialH2O",
  inherit = BinomialGLM,
  cloneable = TRUE, # changing to TRUE to make it easy to clone input h_g0/h_gstar model fits
  portable = TRUE,
  class = TRUE,
  public = list(

    # TO DO: THIS WILL CONTAIN ADDITIONAL USER-SPEC'ED CONTROLS/ARGS PASSED ON TO h2o or h2oEnsemble
    # model.controls = NULL,
    fit.class = c("GLM", "RF", "GBM", "SL"),
    model.fit = list(coef = NA, fitfunname = NA, linkfun = NA, nobs = NA, params = NA, H2O.model.object = NA),

    initialize = function(fit.algorithm, fit.package, ParentModel, ...) {
      self$ParentModel <- ParentModel
      assert_that("h2o" %in% fit.package)
      self$fit.class <- fit.algorithm
      class(self$model.fit) <- c(class(self$model.fit), "h2o" %+% self$fit.class)

      invisible(self)
    },

    fit = function(data, outvar, predvars, subset_idx, ...) {
      # a penalty for being able to obtain predictions from predictAeqA() right after fitting is the need to store Yvals:
      self$setdata(data, subset_idx = subset_idx, getoutvar = TRUE, getXmat = FALSE)
      model.fit <- self$model.fit

      if ((length(predvars) == 0L) || (sum(subset_idx) == 0L)) {
        class(model.fit) <- "try-error"
        message("unable to run " %+% self$fit.class %+% " with h2o for intercept only models or input data with zero observations, running speedglm as a backup...")
      } else {
        rows_subset <- which(subset_idx)
        # subset_t <- system.time(
        #   subsetH2Oframe_1 <- data$H2O.dat.sVar[rows_subset, c(outvar, predvars)]
        # )
        # print("subset_t: "); print(subset_t)
        load_subset_t <- system.time(
          subsetH2Oframe <- data$fast.load.to.H2O(data$dat.sVar[rows_subset, c(outvar, predvars), with = FALSE],
                                                    saveH2O = FALSE,
                                                    destination_frame = "newH2Osubset")
        )
        print("time to subset and load data into H2OFRAME: "); print(load_subset_t)
        # print("length(rows_subset): "); print(length(rows_subset))
        # print("2 frames are equivalent?"); print(all.equal(subsetH2Oframe_1, subsetH2Oframe_2))
        # subsetH2Oframe <- subsetH2Oframe_2

        outfactors <- as.vector(h2o::h2o.unique(subsetH2Oframe[, outvar]))
        # Below being TRUE implies that the conversion to H2O.FRAME produced errors, since there should be no NAs in the source subset data
        NAfactors <- any(is.na(outfactors))

        # fixing bug in h2o frame
        if (NAfactors) {
          message("FOUND NA OUTCOMES IN H2OFRAME WHEN THERE WERE NOT SUPPOSED TO BE ANY")
          NA_idx_h2o <- which(as.logical(is.na(subsetH2Oframe[,outvar])))
          orig.vals <- data$dat.sVar[rows_subset, ][NA_idx_h2o, outvar, with = FALSE][[outvar]]
          # require("h2o")
          subsetH2Oframe[NA_idx_h2o, outvar] <- orig.vals[1]
          outfactors <- as.vector(h2o::h2o.unique(subsetH2Oframe[, outvar]))
          NAfactors <- any(is.na(outfactors))
        }

        if (length(outfactors) < 2L | NAfactors) {
          message("unable to run " %+% self$fit.class %+% " with h2o for input data with constant outcome, running speedglm as a backup...")
          class(model.fit) <- "try-error"
        } else if (length(outfactors) > 2L) {
          stop("cannot run binary regression/classification for outcome with more than 2 categories")
        }
      }

      if (!inherits(model.fit, "try-error")) {
        subsetH2Oframe[, outvar] <- h2o::as.factor(subsetH2Oframe[, outvar])
        private$subsetH2Oframe <- subsetH2Oframe
        model.fit <- try(
                      h2ofit(self$model.fit,
                             subsetH2Oframe = subsetH2Oframe,
                             outvar = outvar,
                             predvars = predvars,
                             rows_subset = rows_subset, ...),
                silent = TRUE)
        if (inherits(model.fit, "try-error")) { # failed, need to define the Xmat now and try fitting speedglm/glm
          self$emptydata
          message("attempt at running " %+% self$fit.class %+% " with h2o failed, running speedglm as a backup...")
        }
      }
      if (inherits(model.fit, "try-error")) { # failed, need to define the Xmat now and try fitting speedglm/glm
        # message("unable to run " %+% self$fit.class %+% " with h2o, running speedglm as a backup...")
        class(self$model.fit)[2] <- "speedglm"
        model.fit <- super$fit(data, outvar, predvars, subset_idx, ...)
      }
      self$model.fit <- model.fit
      return(self$model.fit)
    }
  ),

  active = list( # 2 types of active bindings (w and wout args)
    emptydata = function() { private$subsetH2Oframe <- NULL},
    getsubsetH2Oframe = function() {private$subsetH2Oframe}
  ),

  private = list(
    subsetH2Oframe = NULL
  )
)






