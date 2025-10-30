############################################
# RDS: PostgreSQL in private subnets
############################################

# Strong random password so we never hardcode secrets
resource "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "!#$%^*()-_=+[]{}"
}

# Store creds in Secrets Manager (interview-friendly)
resource "aws_secretsmanager_secret" "db_secret" {
  name        = "rds/postgres/app"
  description = "App DB credentials for EKS backend"
}

resource "aws_secretsmanager_secret_version" "db_secret_value" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = "appuser"
    password = random_password.db_password.result
  })
}

# Subnet group: tells RDS which (private) subnets to use
resource "aws_db_subnet_group" "db_subnets" {
  name       = "app-db-subnets"
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]
  tags = { Name = "app-db-subnets" }
}

# Security Group for RDS: allow only from private CIDRs (and optionally bastion)
resource "aws_security_group" "rds_sg" {
  name        = "rds-postgres-sg"
  description = "Allow Postgres from VPC private subnets (and bastion for debug)"
  vpc_id      = aws_vpc.main.id

  # Allow from private subnets (adjust if your CIDRs differ)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [
      "10.0.3.0/24", # private_subnet_1
      "10.0.4.0/24"  # private_subnet_2
    ]
  }

  # (Optional) Uncomment to allow bastion to psql for debugging
  # ingress {
  #   from_port       = 5432
  #   to_port         = 5432
  #   protocol        = "tcp"
  #   security_groups = [aws_security_group.bastion_sg.id]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rds-postgres-sg" }
}

# (Optional) Parameter group — keep defaults for now
resource "aws_db_parameter_group" "pg_params" {
  name   = "app-postgres-params"
  family = "postgres15"
  description = "Basic PG params for app"
}

# The RDS Instance
resource "aws_db_instance" "postgres" {
  identifier                 = "app-postgres"
  engine                     = "postgres"
  engine_version             = "15.6"          # stable; adjust if region supports different exact patch
  instance_class             = "db.t3.micro"   # cheap for labs
  allocated_storage          = 20
  storage_type               = "gp3"

  # Credentials
  username                   = "appuser"
  password                   = random_password.db_password.result

  # Networking
  db_subnet_group_name       = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids     = [aws_security_group.rds_sg.id]
  publicly_accessible        = false
  multi_az                   = false           # keep cost low in lab

  # Safety / Ops
  deletion_protection        = false           # lab only; true in prod
  skip_final_snapshot        = true            # lab only; avoid snapshot charges
  backup_retention_period    = 1               # short backups (increase in prod)
  auto_minor_version_upgrade = true
  apply_immediately          = true

  parameter_group_name       = aws_db_parameter_group.pg_params.name

  tags = {
    Name = "app-postgres"
    Environment = "lab"
  }

  depends_on = [aws_db_subnet_group.db_subnets]
}

# Handy outputs to wire up the backend
output "db_endpoint" {
  description = "Postgres endpoint (host:port)"
  value       = aws_db_instance.postgres.address
}

output "db_port" {
  value = aws_db_instance.postgres.port
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db_secret.arn
}

