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

# Create a client to access S3.
if (!exists("s3")) {
  s3 <- paws::s3()
}

#' Run a serialized function and arguments, and write its results to S3.
#'
#' @param payload A base64-encoded serialized R list, containing elements:
#'   `function`: A function to run.
#'   `args`: The arguments to the function.
#'   `s3uri`: The S3 path to write outputs to.
#'   `id`: A unique ID; results will be written to a file with this name.
#'
#' @return None.
handler_async <- function(payload) {
  decode <- function(x) unserialize(base64enc::base64decode(x))
  data <- decode(payload)
  f <- data[["function"]]
  args <- data[["args"]]
  result <- do.call(f, args)
  
  bucket <- data[["bucket"]]
  key = data[["key"]]
  
  s3$put_object(
    Body = serialize(result, NULL),
    Bucket = bucket,
    Key = key
  )
}

