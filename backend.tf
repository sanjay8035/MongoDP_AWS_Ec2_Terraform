terraform {
    backend "s3" {
        bucket = "dev-terraform-state-05032022"
        key = "dev/infrastructure.tfstate"
        region = "us-east-2"
        encrypt = "true"
        #dynamodb_table = "${var.api_name}-terraform-locks"
    }
}


resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
  name = "terraform-state-lock-dynamo"
  hash_key = "LockID"
  read_capacity = 20
  write_capacity = 20
 
  attribute {
    name = "LockID"
    type = "S"
  }
}