provider "aws" {
  region = "ap-northeast-1"
}

data "aws_ami" "amazon" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }

  owners = ["amazon"] # Canonical
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id
  security_groups = [aws_security_group.bastion_sg.id]
  key_name      = "teraform-key"

  tags = {
    Name = "learn-terraform"
  }
}

resource "aws_instance" "WorkerNode" {
  count         = 3
  ami           = data.aws_ami.amazon.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_worker.id
  associate_public_ip_address = true
  security_groups = [aws_security_group.worker_sg.id]
  key_name      = "teraform-key"

  tags = {
    Name = "learn-terraform-worker-${count.index}"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

# インターネットゲートウェイの作成
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# パブリックサブネットの作成
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1a"

  tags = {
    Name = "public-subnet"
  }
}

# パブリックワーカーサブネットの作成
resource "aws_subnet" "public_worker" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1a"

  tags = {
    Name = "public-subnet-worker"
  }
}

# パブリックルートテーブルの作成
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_worker_assoc" {
  subnet_id      = aws_subnet.public_worker.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.main.id
  name   = "bastion_sg"
}

resource "aws_security_group_rule" "bastion_sg_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.bastion_sg.id
  source_security_group_id = aws_security_group.worker_sg.id
}

resource "aws_security_group_rule" "bastion_sg_egress" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  cidr_blocks              = ["0.0.0.0/0"]
  security_group_id        = aws_security_group.bastion_sg.id
}

resource "aws_security_group_rule" "bastion_sg_ingress_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  cidr_blocks              = [var.my_public_ip]
  security_group_id        = aws_security_group.bastion_sg.id
}

resource "aws_security_group" "worker_sg" {
  vpc_id = aws_vpc.main.id
  name   = "worker_sg"
}

resource "aws_security_group_rule" "worker_sg_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.worker_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
}

resource "aws_security_group_rule" "worker_sg_internal" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.worker_sg.id
  source_security_group_id = aws_security_group.worker_sg.id
}

resource "aws_security_group_rule" "worker_sg_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.worker_sg.id
}

resource "aws_security_group_rule" "worker_sg_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.worker_sg.id
}

resource "aws_security_group_rule" "worker_sg_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.worker_sg.id
}

resource "local_file" "worker_csrs" {
  count = 3

  content = templatefile("./csr-json/worker-csr.json.tpl", {
    worker_instance  = "learn-terraform-worker-${count.index}"
  })

  filename = "./csr-json/learn-terraform-worker-${count.index}-csr.json"
}
