# vpc:
module "project_vpc" {
  source = "github.com/apahomovs/tf-modules//vpc_module"

  cidr_block        = "10.0.0.0/24"
  create_attach_igw = true
  vpc_tag           = "project_vpc"
}

#create public and private subnets:

# subnets:
module "subnets" {
  source = "github.com/apahomovs/tf-modules//subnet_module"

  for_each = {
  public_1a = ["10.0.0.0/26", "us-east-1a", true, "public_1a" ]
  private_1a = ["10.0.0.64/26", "us-east-1a", false, "private_1a" ]
  public_1b = ["10.0.0.128/26", "us-east-1b", true, "public_1b" ]
  private_1b = ["10.0.0.192/26", "us-east-1b", false, "private_1b" ]
}

  vpc_id                  = module.project_vpc.id
  cidr_block              = each.value[0]
  availability_zone       = each.value[1]
  map_public_ip_on_launch = each.value[2]
  subnet_tag              = each.key
}

#create natgw and eip:


# natgw:
module "natgw" {
  source = "github.com/russgazin/b11-modules.git//natgw_module"

  subnet_id = module.subnets["public_1a"].id
  natgw_tag = "project_natgw"
}

#create public rt:

module "public_rt" {
  source = "github.com/apahomovs/tf-modules//rt_module"

  vpc_id = module.project_vpc.id
  subnets = [module.subnets["public_1a"].id, module.subnets["public_1b"].id]
  gateway_id = module.project_vpc.igw_id
  nat_gateway_id = null
}

# private rtb:
module "private_rt" {
  source = "github.com/russgazin/b11-modules.git//rtb_module"

  vpc_id         = module.project_vpc.id
  gateway_id     = null
  nat_gateway_id = module.natgw.id
  subnets        = [module.subnets["private_1a"].id, module.subnets["private_1b"].id]
}

# security group:

module "sgrp" {
  source = "github.com/apahomovs/tf-modules//sg_module"
  
  name = "ec2_sgrp"
  description = "security group for ec2"
  vpc_id = module.project_vpc.id
  sg_tag = "ec2_sgrp"

  sg_rules = {
  ssh_from_www = ["ingress", 22, 22, "TCP", "0.0.0.0/0"]
  http_from_www   = ["ingress", 80, 80, "TCP", "0.0.0.0/0"]
  outbound_to_www = ["egress", 0, 0, "-1", "0.0.0.0/0"]
}
}

data "aws_ami" "ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm*x86_64-gp2"]
  }
}

data "aws_key_pair" "tentek" {
  key_name = "tentek"
}


# create ec2:

module "ec2_1a" {
  source                 = "github.com/apahomovs/tf-modules//ec2_module"
  ami                    = data.aws_ami.ami.id
  instance_type          = "t2.micro"
  key_name               = "tentek"
  vpc_security_group_ids = [module.sgrp.id] // Note the square brackets around module.sgrp.id
  subnet_id              = module.subnets["public_1a"].id
  user_data              = file("userdata.sh")
  instance_tag           = "public_1a"
}
module "ec2_1b" {
  source                 = "github.com/apahomovs/tf-modules//ec2_module"
  ami                    = data.aws_ami.ami.id
  instance_type          = "t2.micro"
  key_name               = "tentek"
  vpc_security_group_ids = [module.sgrp.id] // Note the square brackets around module.sgrp.id
  subnet_id              = module.subnets["public_1b"].id
  user_data              = file("userdata.sh")
  instance_tag           = "public_1b"
}

#create tg for ec2:

module "tg" {
  source                 = "github.com/apahomovs/tf-modules//tg_module"

  tg_name = "tg-ec2"
  tg_protocol = "HTTP"
  tg_vpc_id = module.project_vpc.id
  tg_port = 80
  tg_tag = "tf-project"
  instance_ids = [module.ec2_1a, module.ec2_1b]
}