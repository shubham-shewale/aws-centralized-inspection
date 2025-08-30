# Enhanced PAN-OS Configuration with Threat Prevention - MEDIUM RISK FIX

# Threat Prevention Profiles
resource "panos_antivirus_security_profile" "comprehensive" {
  name         = "comprehensive-antivirus"
  device_group = var.device_group

  decoder {
    action = "block"
  }

  application {
    action = "block"
  }

  tags = ["inspection", "threat-prevention"]
}

resource "panos_anti_spyware_security_profile" "comprehensive" {
  name         = "comprehensive-anti-spyware"
  device_group = var.device_group

  botnet_domains {
    action = "block"
  }

  rules {
    name   = "default"
    action = "block"
    severity = ["critical", "high", "medium"]
    threat_name = "any"
  }

  tags = ["inspection", "threat-prevention"]
}

resource "panos_vulnerability_security_profile" "comprehensive" {
  name         = "comprehensive-vulnerability"
  device_group = var.device_group

  rules {
    name   = "default"
    action = "block"
    severity = ["critical", "high"]
    cve = "any"
    vendor_id = "any"
  }

  tags = ["inspection", "threat-prevention"]
}

resource "panos_file_blocking_security_profile" "comprehensive" {
  name         = "comprehensive-file-blocking"
  device_group = var.device_group

  rules {
    name = "block-dangerous-files"
    application = "any"
    file_type = ["7z", "bat", "chm", "class", "cpl", "dll", "exe", "hta", "jar", "js", "msi", "ocx", "pif", "ps1", "scr", "vbe", "vbs", "wsf"]
    direction = "both"
  }

  tags = ["inspection", "threat-prevention"]
}

resource "panos_wildfire_analysis_security_profile" "comprehensive" {
  name         = "comprehensive-wildfire"
  device_group = var.device_group

  rules {
    name = "default"
    application = "any"
    file_type = "any"
    direction = "both"
  }

  tags = ["inspection", "threat-prevention"]
}

# URL Filtering Profile
resource "panos_url_filtering_security_profile" "comprehensive" {
  name         = "comprehensive-url-filtering"
  device_group = var.device_group

  credential_enforcement {
    mode = "ip-user"
  }

  alert = ["abortion", "abused-drugs", "adult", "alcohol-and-tobacco", "auctions", "business-and-economy", "command-and-control", "computer-and-internet-info", "content-delivery-networks", "copyright-infringement", "cryptocurrency", "dating", "dynamic-dns", "educational-institutions", "entertainment-and-arts", "extremism", "financial-services", "gambling", "games", "government", "grayware", "hacking", "health-and-medicine", "high-risk", "home-and-garden", "hunting-and-fishing", "insufficient-content", "internet-communications-and-telephony", "internet-portals", "job-search", "legal", "low-risk", "malware", "medium-risk", "military", "motor-vehicles", "music", "news", "not-resolved", "nudity", "online-storage-and-backup", "parked", "peer-to-peer", "personal-sites-and-blogs", "philosophy-and-political-advocacy", "phishing", "private-ip-addresses", "proxy-avoidance-and-anonymizers", "questionable", "real-estate", "recreation-and-hobbies", "reference-and-research", "religion", "search-engines", "sex-education", "shareware-and-freeware", "shopping", "social-networking", "society", "sports", "stock-advice-and-tools", "streaming-media", "swimsuits-and-intimate-apparel", "training-and-tools", "translation", "travel", "unknown", "weapons", "web-advertisements", "web-based-email", "web-hosting"]

  block = ["command-and-control", "hacking", "malware", "phishing"]

  tags = ["inspection", "threat-prevention"]
}

# Security Profile Group
resource "panos_security_profile_group" "comprehensive" {
  name         = "comprehensive-security-profiles"
  device_group = var.device_group

  antivirus = panos_antivirus_security_profile.comprehensive.name
  anti_spyware = panos_anti_spyware_security_profile.comprehensive.name
  vulnerability = panos_vulnerability_security_profile.comprehensive.name
  file_blocking = panos_file_blocking_security_profile.comprehensive.name
  wildfire_analysis = panos_wildfire_analysis_security_profile.comprehensive.name
  url_filtering = panos_url_filtering_security_profile.comprehensive.name

  tags = ["inspection", "threat-prevention"]
}

# Enhanced Security Rules with Threat Prevention
resource "panos_security_rule" "rules" {
  count = length(var.security_rules)

  name                  = var.security_rules[count.index].name
  action                = var.security_rules[count.index].action
  source_zones          = var.security_rules[count.index].source_zones
  destination_zones     = var.security_rules[count.index].destination_zones
  source_addresses      = var.security_rules[count.index].source_addresses
  destination_addresses = var.security_rules[count.index].destination_addresses
  applications          = var.security_rules[count.index].applications
  services              = var.security_rules[count.index].services
  device_group          = var.device_group

  # Apply comprehensive security profiles - MEDIUM RISK FIX
  profile_type {
    group = panos_security_profile_group.comprehensive.name
  }

  # Enable logging
  log_setting = "default"
  log_start   = true
  log_end     = true
}

# Default Deny Rule - MEDIUM RISK FIX
resource "panos_security_rule" "default_deny" {
  name             = "default-deny-all"
  action           = "deny"
  source_zones     = ["any"]
  destination_zones = ["any"]
  source_addresses = ["any"]
  destination_addresses = ["any"]
  applications     = ["any"]
  services         = ["any"]
  device_group     = var.device_group

  # Apply security profiles to default deny
  profile_type {
    group = panos_security_profile_group.comprehensive.name
  }

  # Enable logging for denied traffic
  log_setting = "default"
  log_start   = true
  log_end     = true

  # Place at end of rulebase
  rulebase = "post-rulebase"
}