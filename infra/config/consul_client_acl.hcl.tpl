acl = {
    enabled = true
    default_policy = "deny"
    enable_token_persistence = true
    down_policy = "extend-cache"
    tokens {
      default = "${agent_token}"
      agent = "${agent_token}"
    }
}