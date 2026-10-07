This is a multi module project in the modules folder
awsEKS is the eks cluster
- main.tf has
  official aws vpc
  official eks cluster
- variables
  Expose configurations to the root tier, allowing you to easily alter cluster parameters
awsS3 is the S3 bucket the cluster will use for the state files


main.tf
- This is where your CI/CD pipeline runs execution commands.
- It sources the dynamic S3 backend and calls your local module using a relative directory path.