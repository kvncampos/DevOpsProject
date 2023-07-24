resource "aws_s3_bucket" "mindmeld-bucket-terraform" {
  bucket = "mindmeld-bucket-terraform"
  # Prevent bucket deletion during destroy
  force_destroy = true
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.mindmeld-bucket-terraform.id
  versioning_configuration {
    status = "Enabled"
  }
}


locals {
  s3_api_path = "./api/"
  s3_app_path = "./app/"
}

resource "aws_s3_object" "api" {
  for_each      = fileset(local.s3_api_path, "**")
  bucket        = aws_s3_bucket.mindmeld-bucket-terraform.id
  key           = "${local.s3_api_path}${each.key}"
  source        = "${local.s3_api_path}${each.value}"
  content_type  = "binary/octet-stream"  # Set the desired content type of the uploaded files
}

resource "aws_s3_object" "app" {
  for_each      = fileset(local.s3_app_path, "**")
  bucket        = aws_s3_bucket.mindmeld-bucket-terraform.id
  key           = "${local.s3_app_path}${each.key}"
  source        = "${local.s3_app_path}${each.value}"
  content_type  = "binary/octet-stream"  # Set the desired content type of the uploaded files
}
