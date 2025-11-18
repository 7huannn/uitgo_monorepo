output "network" {
  value = {
    vpc_id          = module.network.vpc_id
    cidr_block      = module.network.cidr_block
    private_subnets = module.network.private_subnet_ids
  }
}

output "databases" {
  value = {
    user   = module.user_db.endpoint
    trip   = module.trip_db.endpoint
    driver = module.driver_db.endpoint
  }
}

output "driver_cache" {
  value = {
    endpoint = module.driver_cache.primary_endpoint
    port     = module.driver_cache.port
  }
}

output "trip_match_queue" {
  value = {
    url = module.trip_match_queue.url
    arn = module.trip_match_queue.arn
  }
}

output "trip_db_replica" {
  value = module.trip_db_replica.endpoint
}

output "autoscaling" {
  value = {
    driver_asg = module.driver_service_asg.asg_name
    trip_asg   = module.trip_service_asg.asg_name
  }
}
