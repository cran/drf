% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/drf.R
\name{predict.drf}
\alias{predict.drf}
\title{Predict with a drf forest}
\usage{
\method{predict}{drf}(
  object,
  newdata = NULL,
  transformation = NULL,
  functional = NULL,
  num.threads = NULL,
  custom.functional = function(y, w) apply(y, 2, sum(y * w)),
  ...
)
}
\arguments{
\item{object}{The trained drf forest.}

\item{newdata}{Points at which predictions should be made. If NULL, makes out-of-bag
predictions on the training set instead (i.e., provides predictions at
Xi using only trees that did not use the i-th training example). Note
that this matrix (or vector) should have the number of columns as the training
matrix, and that the columns must appear in the same order.}

\item{transformation}{a function giving a transformation of the responses, by default if NULL, the identity \code{function(y) y} is used.}

\item{functional}{which type of statistical functional. One option between:
\itemize{
 \item{"mean"}{the conditional mean, the returned value is a list containing a matrix \code{mean} of size \code{n} x \code{f},
 where \code{n} denotes the number of observation in \code{newdata} and \code{f} the dimension of the \code{transformation}.}
 \item{"sd"}{the conditional standard deviation, the returned value is a list containing a matrix \code{sd} of size \code{n} x \code{f},
 where \code{n} denotes the number of observation in \code{newdata} and \code{f} the dimension of the \code{transformation}.}
 \item{"quantile"}{the conditional quantiles, the returned value is a list containing an array \code{quantile} of size \code{n} x \code{f}  x \code{q},
 where \code{n} denotes the number of observation in \code{newdata}, \code{f} the dimension of the \code{transformation} and \code{q} the number of desired quantiles.}
 \item{"cor"}{the conditional correlation, the returned value is a list containing an array \code{cor} of size \code{n} x \code{f}  x \code{f},
 where \code{n} denotes the number of observation in \code{newdata}, \code{f} the dimension of the \code{transformation}.}
\item{"cov"}{the conditional covariance, the returned value is a list containing an array \code{cor} of size \code{n} x \code{f}  x \code{f},
 where \code{n} denotes the number of observation in \code{newdata}, \code{f} the dimension of the \code{transformation}.}
 \item{"normalPredictionScore"}{a prediction score based on an asymptotic normality assumption, the returned value is a list containing a list of functions \code{normalPredictionScore} of size \code{n},
 where \code{n} denotes the number of observation in \code{newdata}. Here the transformation should be uni-dimensional.}
 \item{"custom"}{a custom function provided by the user, the returned value is a list containing a matrix \code{custom} of size \code{n} x \code{f},
 where \code{n} denotes the number of observation in \code{newdata} and \code{f} the dimension of the output of the function \code{custom.functional}.}
 \item{"MQ"}{multivariate quantiles, return a list containing a matrix of the inputed ranks u (that should be provided as an argument of the predict function) along with a list of the different corresponding MQ (same size as u).}
}}

\item{num.threads}{Number of threads used in training. If set to NULL, the software
automatically selects an appropriate amount.}

\item{custom.functional}{a function giving the custom functional when \code{functional} is set to "custom". This should be a function \code{f(y,w)} using the
training response matrix \code{y} and the weights \code{w} at a single testing point.}

\item{...}{additional parameters.}
}
\value{
a list containing an entry with the same name as the functional selected.
}
\description{
Predict with a drf forest
}
\examples{
# Train a distributional random forest with CART splitting rule.
n <- 100
p <- 2
X <- matrix(rnorm(n * p), n, p)
Y <- X + matrix(rnorm(n * p), ncol=p)
drf.forest <- drf(X = X, Y = Y)

# Predict conditional correlation.
X.test <- matrix(0, 101, p)
X.test[, 1] <- seq(-2, 2, length.out = 101)
cor.pred <- predict(drf.forest, X.test, functional = "cor")

# Predict on out-of-bag training samples.
cor.oob.pred <- predict(drf.forest,  functional = "cor")

# Train a distributional random forest with "FourierMMD" splitting rule.
n <- 100
p <- 2
X <- matrix(rnorm(n * p), n, p)
Y <- X + matrix(rnorm(n * p), ncol=p)
drf.forest <- drf(X = X, Y = Y, splitting.rule = "FourierMMD", num.features = 10)

# Predict conditional correlation.
X.test <- matrix(0, 101, p)
X.test[, 1] <- seq(-2, 2, length.out = 101)
cor.pred <- predict(drf.forest, X.test, functional = "cor")

# Predict on out-of-bag training samples.
cor.oob.pred <- predict(drf.forest,  functional = "cor")


}
