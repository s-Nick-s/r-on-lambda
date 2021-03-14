# Demonstrate running R code on AWS Lambda, e.g.
# ```
# run(function(a, b) a + b, list(a = 1, b = 2)) # result: 3
# ````

# Create a Docker image and push it to your registry.
# See https://mdneuzerling.com/post/r-on-aws-lambda-with-containers/
# or the instructions in the ECR console.
docker_image_uri <- "123456789012.dkr.ecr.us-east-1.amazonaws.com/r-on-lambda:latest"

#-------------------------------------------------------------------------------

# Create an IAM role for the Lambda function.
# Not sure if this is needed.
iam <- paws::iam()
role_name <- "r-on-lambda"
policy_arn <- "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

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

role <- iam$create_role(
  RoleName = role_name,
  AssumeRolePolicyDocument = jsonlite::toJSON(trust_policy, auto_unbox = TRUE)
)

iam$attach_role_policy(
  RoleName = role_name,
  PolicyArn = policy_arn
)

#-------------------------------------------------------------------------------

# Set up Lambda function.
lambda <- paws::lambda()

lambda$create_function(
  FunctionName = "r-on-lambda",
  PackageType = "Image",
  Code = list(
    ImageUri = docker_image_uri
  ),
  ImageConfig = list(
    Command = list(
      "functions.handler"
    )
  ),
  Timeout = 30,
  Role = role$Role$Arn
)

#-------------------------------------------------------------------------------

# Serialize data.
get_args <- function(f, args) {
  encode <- function(x) base64enc::base64encode(serialize(x, NULL))
  data <- list(
    "function" = f,
    "args" = args
  )
  return(jsonlite::toJSON(list(payload = encode(data)), auto_unbox = TRUE))
}

#-------------------------------------------------------------------------------

# Run the given function `f` with arguments in named list `args`.
run <- function(f, args) {
  resp <- lambda$invoke(
    FunctionName = "r-on-lambda",
    InvocationType = "RequestResponse", 
    Payload = get_args(f, args)
  )
  result <- jsonlite::fromJSON(rawToChar(resp$Payload))
  return(result$result)
}

run(function(a, b, c) a + b + c, list(a = 1, b = 2, c = 3))

#-------------------------------------------------------------------------------

# Run the given function `f` with arguments in named list `args`.
run_async <- function(f, args) {
  resp <- lambda$invo(
    FunctionName = "r-on-lambda",
    InvocationType = "Event", 
    Payload = get_args(f, args)
  )
  return(resp)
}

run(function(a, b, c) a + b + c, list(a = 1, b = 2, c = 3))


