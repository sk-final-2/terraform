resource "aws_db_parameter_group" "mariadb_utf8mb4" {
  name        = "${var.name}-mariadb-utf8mb4"
  family      = "mariadb10.6"
  description = "utf8mb4 default charset/collation"

  parameter {
    name         = "character_set_server"
    value        = "utf8mb4"
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "collation_server"
    value        = "utf8mb4_unicode_ci"
    apply_method = "pending-reboot"
  }
}
