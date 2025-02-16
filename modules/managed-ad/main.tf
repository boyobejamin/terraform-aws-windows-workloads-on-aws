## Sets providers settings

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "msft_python_automation"
}

## Sets Admin secret

resource "random_password" "mad_admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "mad_admin_secret" {
  name       = "${var.ds_managed_ad_directory_name}_${local.ds_managed_ad_admin_secret_sufix}"
  kms_key_id = var.ds_managed_ad_secret_key
  recovery_window_in_days = 30
}

resource "aws_secretsmanager_secret_version" "mad_admin_secret_version" {
  secret_id     = aws_secretsmanager_secret.mad_admin_secret.id
  secret_string = random_password.mad_admin_password.result
}

## MAD deployment

resource "aws_directory_service_directory" "ds_managed_ad" {
  name       = var.ds_managed_ad_directory_name
  short_name = var.ds_managed_ad_short_name
  password   = aws_secretsmanager_secret_version.mad_admin_secret_version.secret_string
  edition    = var.ds_managed_ad_edition
  type       = local.ds_managed_ad_type

  vpc_settings {
    vpc_id     = var.vpc_id
    subnet_ids = [var.private_subnet_id_1, var.private_subnet_id_2]
  }
}

## Sets MAD security group egress

resource "aws_security_group_rule" "ds_managed_ad_secgroup" {
  type              = "egress"
  description       = "Allowing outbound traffic"
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  security_group_id = aws_directory_service_directory.ds_managed_ad.security_group_id
}
