#' Retrieve a single tree from a trained forest object.
#'
#' @param forest The trained forest.
#' @param index The index of the tree to retrieve.
#'
#' @return A DRF tree object containing the below attributes.
#'     drawn_samples: a list of examples that were used in training the tree. This includes
#'     examples that were used in choosing splits, as well as the examples that populate the leaf
#'     nodes. Put another way, if honesty is enabled, this list includes both subsamples from the
#'     split (J1 and J2 in the notation of the paper).
#'     num_samples: the number of examples used in training the tree.
#'     nodes: a list of objects representing the nodes in the tree, starting with the root node. Each
#'     node will contain an 'is_leaf' attribute, which indicates whether it is an interior or leaf node.
#'     Interior nodes contain the attributes 'left_child' and 'right_child', which give the indices of
#'     their children in the list, as well as 'split_variable', and 'split_value', which describe the
#'     split that was chosen. Leaf nodes only have the attribute 'samples', which is a list of the
#'     training examples that the leaf contains. Note that if honesty is enabled, this list will only
#'     contain examples from the second subsample that was used to 'repopulate' the tree (J2 in the
#'     notation of the paper).
#'
#' @examples
#' \dontrun{
#' # Train a quantile forest.
#' n <- 50
#' p <- 10
#' X <- matrix(rnorm(n * p), n, p)
#' Y <- X[, 1] * rnorm(n)
#' q.forest <- quantile_forest(X, Y, quantiles = c(0.1, 0.5, 0.9))
#'
#' # Examine a particular tree.
#' q.tree <- get_tree(q.forest, 3)
#' q.tree$nodes
#' }
#'
#' @export
get_tree <- function(forest, index) {
  if (index < 1 || index > forest[["_num_trees"]]) {
    stop(paste("The provided index,", index, "is not valid."))
  }

  # Convert internal grf representation to adjacency list.
  # +1 from C++ to R index.
  root <- forest[["_root_nodes"]][[index]] + 1
  left <- forest[["_child_nodes"]][[index]][[1]]
  right <- forest[["_child_nodes"]][[index]][[2]]
  split_vars <- forest[["_split_vars"]][[index]]
  split_values <- forest[["_split_values"]][[index]]
  leaf_samples <- forest[["_leaf_samples"]][[index]]
  drawn_samples <- forest[["_drawn_samples"]][[index]] + 1

  nodes <- list()
  frontier <- root
  i <- 0
  node.index <- 1
  while (length(frontier) > 0) {
    node <- frontier[1]
    frontier <- frontier[-1]
    i <- i + 1
    if (left[[node]] == 0 && right[[node]] == 0) {
      nodes[[i]] <- list(
        is_leaf = TRUE,
        samples = leaf_samples[[node]] + 1
      )
    } else {
      nodes[[i]] <- list(
        is_leaf = FALSE,
        split_variable = split_vars[node] + 1,
        split_value = split_values[node],
        left_child = node.index + 1,
        right_child = node.index + 2
      )
      node.index <- node.index + 2
      frontier <- c(left[node] + 1, right[node] + 1, frontier)
    }
  }

  tree <- list()
  tree$num_samples <- length(drawn_samples)
  tree$drawn_samples <- drawn_samples
  tree$nodes <- nodes

  columns <- colnames(forest$X.orig)
  indices <- 1:ncol(forest$X.orig)
  tree$columns <- sapply(indices, function(i) {
    if (!is.null(columns) & length(columns[i]) > 0) {
      columns[i]
    } else {
      paste("X", i, sep = ".")
    }
  })

  # for each node, calculate the leaf stats
  tree$nodes <- lapply(tree$nodes, function(node) {
    if (node$is_leaf) {
      node$leaf_stats <- leaf_stats(forest, node$samples)
    }
    node
  })

  class(tree) <- "grf_tree"
  tree
}

#' Calculate which features the forest split on at each depth.
#'
#' @param forest The trained forest.
#' @param max.depth Maximum depth of splits to consider.
#'
#' @return A matrix of split depth by feature index, where each value
#' is the number of times the feature was split on at that depth.
#'
#' @examples
#' \dontrun{
#' # Train a quantile forest.
#' n <- 50
#' p <- 10
#' X <- matrix(rnorm(n * p), n, p)
#' Y <- X[, 1] * rnorm(n)
#' q.forest <- quantile_forest(X, Y, quantiles = c(0.1, 0.5, 0.9))
#'
#' # Calculate the split frequencies for this forest.
#' split_frequencies(q.forest)
#' }
#'
#' @export
split_frequencies <- function(forest, max.depth = 4) {
  raw <- compute_split_frequencies(forest, max.depth)
  feature.indices <- 1:ncol(forest$X.orig)
  raw[, feature.indices, drop = FALSE]
}

#' Calculate a simple measure of 'importance' for each feature.
#'
#' A simple weighted sum of how many times feature i was split on at each depth in the forest.
#'
#' @param forest The trained forest.
#' @param decay.exponent A tuning parameter that controls the importance of split depth.
#' @param max.depth Maximum depth of splits to consider.
#'
#' @return A list specifying an 'importance value' for each feature.
#'
#' @examples
#' \dontrun{
#' # Train a quantile forest.
#' n <- 50
#' p <- 10
#' X <- matrix(rnorm(n * p), n, p)
#' Y <- X[, 1] * rnorm(n)
#' q.forest <- quantile_forest(X, Y, quantiles = c(0.1, 0.5, 0.9))
#'
#' # Calculate the 'importance' of each feature.
#' variable_importance(q.forest)
#' }
#'
#' @export
variable_importance <- function(forest, decay.exponent = 2, max.depth = 4) {
  split.freq <- split_frequencies(forest, max.depth)
  split.freq <- split.freq / pmax(1L, rowSums(split.freq))
  weight <- seq_len(nrow(split.freq))^-decay.exponent
  t(split.freq) %*% weight / sum(weight)
}

#' Given a trained forest and test data, compute the training sample weights for each test point.
#'
#' During normal prediction, these weights are computed as an intermediate step towards producing estimates.
#' This function allows for examining the weights directly, so they could be potentially be used as the
#' input to a different analysis.
#'
#' @param forest The trained forest.
#' @param newdata Points at which predictions should be made. If NULL,
#'                makes out-of-bag predictions on the training set instead
#'                (i.e., provides predictions at Xi using only trees that did
#'                not use the i-th training example).#' @param max.depth Maximum depth of splits to consider.
#' @param num.threads Number of threads used in training. If set to NULL, the software
#'                    automatically selects an appropriate amount.
#' @return A sparse matrix where each row represents a test sample, and each column is a sample in the
#'         training data. The value at (i, j) gives the weight of training sample j for test sample i.
#'
#' @examples
#' \dontrun{
#' p <- 10
#' n <- 100
#' X <- matrix(2 * runif(n * p) - 1, n, p)
#' Y <- (X[, 1] > 0) + 2 * rnorm(n)
#' rrf <- drf(X, matrix(Y,ncol=1), mtry = p)
#' sample.weights.oob <- get_sample_weights(rrf)
#'
#' n.test <- 15
#' X.test <- matrix(2 * runif(n.test * p) - 1, n.test, p)
#' sample.weights <- get_sample_weights(rrf, X.test)
#' }
#'
#' @export
get_sample_weights <- function(forest, newdata = NULL, num.threads = NULL) {
  num.threads <- validate_num_threads(num.threads)

  forest.short <- forest[-which(names(forest) == "X.orig")]
  train.data <- create_data_matrices(forest[["X.orig"]])

  if (!is.null(newdata)) {
    data <- create_data_matrices(newdata)
    compute_weights(
      forest.short, train.data$train.matrix, train.data$sparse.train.matrix,
      data$train.matrix, data$sparse.train.matrix, num.threads
    )
  } else {
    compute_weights_oob(forest.short, train.data$train.matrix, train.data$sparse.train.matrix, num.threads)
  }
}

leaf_stats <- function(forest, samples) UseMethod("leaf_stats")

#' A default leaf_stats for forests classes without a leaf_stats method
#' that always returns NULL.
#' @param forest Any forest
#' @param samples The samples to include in the calculations.
#' @param ... Additional arguments (currently ignored).
#'
#' @return NULL
#'
#' @method leaf_stats default
leaf_stats.default <- function(forest, samples, ...){
  return(NULL)
}

#' Calculate summary stats given a set of samples for regression forests.
#' @param forest The GRF forest
#' @param samples The samples to include in the calculations.
#' @param ... Additional arguments (currently ignored).
#'
#' @return A named vector containing summary stats
#'
#' @method leaf_stats drf
leaf_stats.drf <- function(forest, samples, ...){
  leaf_stats <- c()
  leaf_stats["avg_Y"] <- round(mean(forest$Y.orig[samples]), 2)
  return(leaf_stats)
}

#' Compute the median heuristic for the MMD bandwidth choice
#' @param Y the response matrix
#'
#' @return the median heuristic
medianHeuristic <- function(Y) {
  return(stats::median(sqrt(stats::dist(Y)/2)))
}

#' Weighted quantiles
#' @param x a vector of observations
#' @param w a vector of weights
#' @param probs the given probabilities for which we want to get quantiles
#' @param na.rm should we remove missing values.
weighted.quantile <- function(x, w, probs=seq(0,1,0.25), na.rm=TRUE) {
  x <- as.numeric(as.vector(x))
  w <- as.numeric(as.vector(w))
  if(anyNA(x) || anyNA(w)) {
    ok <- !(is.na(x) | is.na(w))
    x <- x[ok]
    w <- w[ok]
  }
  stopifnot(all(w >= 0))
  if(all(w == 0)) stop("All weights are zero", call.=FALSE)
  #'
  oo <- order(x)
  x <- x[oo]
  w <- w[oo]
  Fx <- cumsum(w)/sum(w)
  #'
  result <- numeric(length(probs))
  for(i in seq_along(result)) {
    p <- probs[i]
    lefties <- which(Fx <= p)
    if(length(lefties) == 0) {
      result[i] <- x[1]
    } else {
      left <- max(lefties)
      result[i] <- x[left]
      if(Fx[left] < p && left < length(x)) {
        right <- left+1
        y <- x[left] + (x[right]-x[left]) * (p-Fx[left])/(Fx[right]-Fx[left])
        if(is.finite(y)) result[i] <- y
      }
    }
  }
  names(result) <- paste0(format(100 * probs, trim = TRUE), "%")
  return(result)
}