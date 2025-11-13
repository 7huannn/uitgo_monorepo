output "network" {
  value = {
    vpc_id      = module.network.vpc_id
    cidr_block  = module.network.cidr_block
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
