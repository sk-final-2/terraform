resource "aws_db_subnet_group" "db" {
  name       = "${var.name}-db-subnets"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_db_instance" "mariadb" {
  identifier              = "${var.name}-mariadb"
  engine                  = "mariadb"
  engine_version          = "10.6"
  parameter_group_name    = aws_db_parameter_group.mariadb_utf8mb4.name
  instance_class          = "db.t3.small"
  allocated_storage       = 50
  storage_type            = "gp3"
  username                = var.db_username
  password                = var.db_password
  db_name                 = "recruit"
  port                    = 3306
  db_subnet_group_name    = aws_db_subnet_group.db.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  publicly_accessible     = false
  multi_az                = false
  deletion_protection     = false
  skip_final_snapshot     = true
  backup_retention_period = 7
  apply_immediately       = true
  storage_encrypted       = true

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
}
