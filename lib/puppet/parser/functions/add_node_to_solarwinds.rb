require "uri"
require "yaml"
require "json"
require "net/http"

# This is a custom function to add nodes to Solarwinds that aren't already there.
# This function uses only SNMPV3 to connect to solarwinds.

module Puppet::Parser::Functions
  newfunction(:add_node_to_solarwinds) do |args|
    config = {}    

    config["username"]  = call_function('hiera',['solarwinds_functions::config::username'])
    config["password"]  = call_function('hiera',['solarwinds_functions::config::password'])
    config["queryurl"]  = call_function('hiera',['solarwinds_functions::config::queryurl'])
    config["addurl"]    = call_function('hiera',['solarwinds_functions::config::addurl'])
    config["snmpv3username"] = call_function('hiera',['solarwinds_functions::config::snmpv3username'])
    config["snmpv3privmethod"] = call_function('hiera',['solarwinds_functions::config::snmpv3privmethod'])
    config["snmpv3privkey"] = call_function('hiera',['solarwinds_functions::config::snmpv3privkey'])
    config["snmpv3authmethod"] = call_function('hiera',['solarwinds_functions::config::snmpv3authmethod'])
    config["snmpv3authkey"] = call_function('hiera',['solarwinds_functions::config::snmpv3authkey'])
    config["pollers"]   = call_function('hiera',['solarwinds_functions::config::pollers'])
    config["engineid"]  = config["pollers"].split(",").sample
    config["nodename"]  = lookupvar('fqdn')
    config["ipaddr"]    = lookupvar('ipaddress')

    response = checkstatus(config)

    if response == '{"results":[]}'
      addhost(config)
    end

  end
end

# Reach out to the Solarwinds (Orion) API and ask if the host is present
def checkstatus(config)

  uri = URI.parse("#{config["queryurl"]}")
  query = {"query" => "SELECT NodeID FROM Orion.Nodes WHERE NodeName=@name", "parameters" => {"name" => "#{config["nodename"]}"}}

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  
  request = Net::HTTP::Post.new(uri.request_uri, initheader = {'Content-Type' =>'application/json'})
  request.body = query.to_json
  request.basic_auth("#{config["username"]}", "#{config["password"]}")

  response = http.request(request)

  return response.body.to_s
end

# If the host was not present in the checkstatus() method, then we add it
def addhost(config)

  uri = URI.parse("#{config["addurl"]}")
  node = { "EntityType" => "Orion.Nodes", "IPAddress" => "#{config["ipaddr"]}",
    "Caption"=> "#{config["nodename"]}", "DynamicIP" => "False", "EngineID" => "#{config["engineid"]}", 
    "Status" => 1, "UnManaged" => "False", "Allow64BitCounters" => "True", 
    "SysObjectID" => "", "MachineType" => "", "VendorIcon" => "", 
    "ObjectSubType" => "SNMP", "SNMPVersion" => 3, "SNMPV3Username" => "#{config["snmpv3username"]}", "SNMPV3Context" => "", "SNMPV3PrivKey" => "#{config["snmpv3privkey"]}", "SNMPV3PrivKeyIsPwd" => 1, "SNMPV3PrivMethod" => "#{config["snmpv3privmethod"]}", "SNMPV3AuthMethod" => "#{config["snmpv3authmethod"]}", "SNMPV3AuthKey" => "#{config["snmpv3authkey"]}", "SNMPV3AuthKeyIsPwd" => 1,
  }

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Post.new(uri.request_uri, initheader = {'Content-Type' =>'application/json'})
  request.body = node.to_json
  request.basic_auth("#{config["username"]}", "#{config["password"]}")

  response = http.request(request)
end
