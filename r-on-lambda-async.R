# Demonstrate running R code on AWS Lambda asynchronously, e.g.
# ```
# run_async(function() Sys.sleep(20))
# ````

# Create a Docker image and push it to your registry.
# See https://mdneuzerling.com/post/r-on-aws-lambda-with-containers/
# or the instructions in the ECR console.
docker_image_uri <- "012345678901.dkr.ecr.us-east-1.amazonaws.com/r-on-lambda:latest"

iam <- paws::iam()
lambda <- paws::lambda()
s3 <- paws::s3()

#-------------------------------------------------------------------------------

# Create an IAM role for the Lambda function.
# Not sure if this is needed.
role_name <- "r-on-lambda"

trust_policy <- list(
  Version = "2012-10-17",
  Statement = list(
    list(
      Effect = "Allow",
      Principal = list(
        Service = "lambda.amazonaws.com"
      ),
      Action = "sts:AssumeRole"
    )
  )
)

create_role <- function(iam, role_name, trust_policy) {
  role <- iam$create_role(
    RoleName = role_name,
    AssumeRolePolicyDocument = jsonlite::toJSON(trust_policy, auto_unbox = TRUE)
  )
  return(role)
}

get_role <- function(iam, role_name) {
  role <- iam$get_role(
    RoleName = role_name
  )
  return(role)
}

role <- tryCatch(
  create_role(iam, role_name, trust_policy),
  error = function(e) get_role(iam, role_name)
)

policies <- c(
  "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
  "arn:aws:iam::aws:policy/AmazonS3FullAccess"
)
for (policy in policies) {
  iam$attach_role_policy(
    RoleName = role_name,
    PolicyArn = policy
  )
}

#-------------------------------------------------------------------------------

# Set up Lambda function.
lambda$create_function(
  FunctionName = "r-on-lambda-async",
  PackageType = "Image",
  Code = list(
    ImageUri = docker_image_uri
  ),
  ImageConfig = list(
    Command = list(
      "functions.handler_async"
    )
  ),
  Timeout = 30,
  Role = role$Role$Arn
)

#-------------------------------------------------------------------------------

# Serialize data.
get_args <- function(f, f_args, ...) {
  encode <- function(x) base64enc::base64encode(serialize(x, NULL))
  data <- list(
    "function" = f,
    "args" = f_args
  )
  v_args <- list(...)
  for (name in names(v_args)) {
    data[[name]] <- v_args[[name]]
  }
  return(jsonlite::toJSON(list(payload = encode(data)), auto_unbox = TRUE))
}

# Extract the bucket and key from an S3 URI like "bucket/foo/bar.
parse_s3_uri <- function(uri) {
  path <- strsplit(uri, "/")[[1]]
  parsed <- list(
    bucket = path[1],
    key = paste(path[2:length(path)], collapse = "/")
  )
  return(parsed)
}

#-------------------------------------------------------------------------------

# Run the given function `f` with arguments in named list `args`.
run_async <- function(f, args = list(), s3_uri = NULL) {
  if (is.null(s3_uri)) stop("missing S3 URI")
  id <- uuid::UUIDgenerate()
  s3_uri <- parse_s3_uri(s3_uri)
  bucket <- s3_uri$bucket
  key <- sprintf("%s/%s", s3_uri$key, id)
  resp <- lambda$invoke(
    FunctionName = "r-on-lambda-async",
    InvocationType = "Event", 
    Payload = get_args(f, args, bucket = bucket, key = key)
  )
  return(id)
}

# Get the result, if available.
get_result <- function(id, s3_uri) {
  s3_uri <- parse_s3_uri(s3_uri)
  bucket <- s3_uri$bucket
  key <- sprintf("%s/%s", s3_uri$key, id)
  check <- tryCatch(
    {s3$head_object(Bucket = bucket, Key = key)},
    error = function(e) e
  )
  if (inherits(check, "http_404")) {
    return()
  }
  resp <- s3$get_object(Bucket = bucket, Key = key)
  result <- unserialize(resp$Body)
  return(result)
}

#-------------------------------------------------------------------------------

s3_uri <- "my-bucket/my-folder"

f <- function(num) {Sys.sleep(20); return(num)}

# Submit the job and get its ID.
id <- run_async(f, list(num = 15), s3_uri = s3_uri)

# Check until the job is done.
i <- 1
result <- NULL
while (is.null(result)) {
  print(sprintf("try: %i", i))
  result <- get_result(id, s3_uri)
  Sys.sleep(1)
  i <- i + 1
}
print(result)
