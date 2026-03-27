acl = {
    enabled = true
    default_policy = "deny"
    enable_token_persistence = true
    down_policy = "extend-cache"
    tokens {
      initial_management = "${management_token}"
      agent = "${management_token}"
    }
}