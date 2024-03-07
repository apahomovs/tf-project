#create vpc
module "project_vpc" {
  source = "github.com/apahomovs/tf-modules//vpc_module"
  cidr_block = "10.0.0.0/24"
  vpc_tag = "project_vpc"
  create_attach_igw = true
}


