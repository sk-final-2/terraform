output "alb_dns" { value = aws_lb.this.dns_name }
output "db_endpoint" { value = aws_db_instance.mariadb.address }
output "redis_endpoint" { value = aws_elasticache_replication_group.redis.primary_endpoint_address }
output "namespace" { value = aws_service_discovery_private_dns_namespace.ns.name }
