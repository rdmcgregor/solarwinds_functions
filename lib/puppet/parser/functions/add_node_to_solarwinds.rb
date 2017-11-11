require 'uri'
require 'yaml'
require 'json'
require 'net/http'

# This is a custom function to add nodes to Solarwinds that aren't already there.
# This function can use either SNMP Version 2 or 3 to connect to solarwinds.
# It assumes that Windows hosts are V2 and everything else is V3

module Puppet::Parser::Functions
  newfunction(:add_node_to_solarwinds) do |_args|
    config = {}

    config['username']          = call_function('hiera', ['solarwinds_functions::config::username'])
    config['password']          = call_function('hiera', ['solarwinds_functions::config::password'])
    config['queryurl']          = call_function('hiera', ['solarwinds_functions::config::queryurl'])
    config['addurl']            = call_function('hiera', ['solarwinds_functions::config::addurl'])
    config['community']         = call_function('hiera', ['solarwinds_functions::config::community'])
    config['snmpv3username']    = call_function('hiera', ['solarwinds_functions::config::snmpv3username'])
    config['snmpv3privmethod']  = call_function('hiera', ['solarwinds_functions::config::snmpv3privmethod'])
    config['snmpv3privkey']     = call_function('hiera', ['solarwinds_functions::config::snmpv3privkey'])
    config['snmpv3authmethod']  = call_function('hiera', ['solarwinds_functions::config::snmpv3authmethod'])
    config['snmpv3authkey']     = call_function('hiera', ['solarwinds_functions::config::snmpv3authkey'])
    config['pollers']           = call_function('hiera', ['solarwinds_functions::config::pollers'])
    config['engineid']          = config['pollers'].split(',').sample
    config['nodename']          = lookupvar('fqdn')
    config['ipaddr']            = lookupvar('ipaddress')
    config['osname']            = lookupvar('osfamily')

    if config['osname'] == 'Windows'
      # for now, we will assume that we are stuck with V2 for Windows
      config['SNMPVersion'] = 2
    else
      config['SNMPVersion'] = 3
    end

    response = checkstatus(config)

    addhost(config) if response == '{"results":[]}'
  end
end

# Reach out to the Solarwinds (Orion) API and ask if the host is present
def checkstatus(config)
  uri = URI.parse((config['queryurl']).to_s)
  query = { 'query' => 'SELECT NodeID FROM Orion.Nodes WHERE NodeName=@name', 'parameters' => { 'name' => (config['nodename']).to_s } }

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Post.new(uri.request_uri, initheader = { 'Content-Type' => 'application/json' })
  request.body = query.to_json
  request.basic_auth((config['username']).to_s, (config['password']).to_s)

  response = http.request(request)

  response.body.to_s
end

# If the host was not present in the checkstatus() method, then we add it
def addhost(config)
  uri = URI.parse((config['addurl']).to_s)
  if config['SNMPVersion'] == 2
    # do V2
    node = { 'EntityType' => 'Orion.Nodes', 'IPAddress' => (config['ipaddr']).to_s,
             'Caption' => (config['nodename']).to_s, 'DynamicIP' => 'False', 'EngineID' => (config['engineid']).to_s,
             'Status' => 1, 'UnManaged' => 'False', 'Allow64BitCounters' => 'True',
             'SysObjectID' => '', 'MachineType' => '', 'VendorIcon' => '',
             'ObjectSubType' => 'SNMP', 'SNMPVersion' => config['SNMPVersion'], 'Community' => (config['community']).to_s }
  else
    # do V3
    node = { 'EntityType' => 'Orion.Nodes', 'IPAddress' => (config['ipaddr']).to_s,
             'Caption' => (config['nodename']).to_s, 'DynamicIP' => 'False', 'EngineID' => (config['engineid']).to_s,
             'Status' => 1, 'UnManaged' => 'False', 'Allow64BitCounters' => 'True',
             'SysObjectID' => '', 'MachineType' => '', 'VendorIcon' => '',
             'ObjectSubType' => 'SNMP', 'SNMPVersion' => config['SNMPVersion'], 'SNMPV3Username' => (config['snmpv3username']).to_s, 'SNMPV3Context' => '', 'SNMPV3PrivKey' => (config['snmpv3privkey']).to_s, 'SNMPV3PrivKeyIsPwd' => 1, 'SNMPV3PrivMethod' => (config['snmpv3privmethod']).to_s, 'SNMPV3AuthMethod' => (config['snmpv3authmethod']).to_s, 'SNMPV3AuthKey' => (config['snmpv3authkey']).to_s, 'SNMPV3AuthKeyIsPwd' => 1 }
  end

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Post.new(uri.request_uri, initheader = { 'Content-Type' => 'application/json' })
  request.body = node.to_json
  request.basic_auth((config['username']).to_s, (config['password']).to_s)

  response = http.request(request)
end
