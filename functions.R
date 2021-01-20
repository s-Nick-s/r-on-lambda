#' Run a serialized function and arguments, and return in a list.
#'
#' @param payload A base64-encoded serialized R list, containing elements:
#'   `function`: A function to run.
#'   `args`: The arguments to the function.
#'
#' @return A list with element `result` with the result of the function call.
handler <- function(payload) {
  decode <- function(x) unserialize(base64enc::base64decode(x))
  data <- decode(payload)
  f <- data[["function"]]
  args <- data[["args"]]
  return(list(result = do.call(f, args)))
}
