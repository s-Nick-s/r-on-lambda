# R on AWS Lambda

This is an attempt to get an R runtime and function working on AWS Lambda using a container.

## Docker push commands

Once you create your ECR repository, do the following to push your image to it.

1. Retrieve an authentication token and authenticate your Docker client to your
registry.
Use the AWS CLI:
```
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
```

Note: If you receive an error using the AWS CLI, make sure that you have the
latest version of the AWS CLI and Docker installed.

2. Build your Docker image using the following command. For information on
building a Docker file from scratch see the instructions here . You can skip
this step if your image is already built:
```
docker build -t r-on-lambda .
```

3. After the build completes, tag your image so you can push the image to this
repository:
```
docker tag r-on-lambda:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/r-on-lambda:latest
```

4. Run the following command to push this image to your newly created AWS
repository:
```
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/r-on-lambda:latest
```
