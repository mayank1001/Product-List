#!/usr/bin/env ruby

require 'yaml'

require_relative 'simple_blue_green_helper.rb'
require_relative 'route.rb'

# Blue-Green-Deployment script
class BlueGreenDeployer
  include BlueGreenHelper # helper methods

  def do_blue_green_deployment(app_name)
    login @username, @password, @endpoint, @organization, @space

    manifest_file_path = "manifest.yml"
    main_route = get_main_route(app_name, @space, manifest_file_path)
    puts "- The Main Route for the deployment is #{main_route}"

    # check blue or green deployed, decide which one to deploy and which one to stop
    current_color = get_deployed_color(app_name, main_route)
    new_color = get_other_color(current_color)
    app_name_to_deploy = "#{app_name}#{new_color}"
    app_host_to_deploy = "#{app_name}-#{@space}#{new_color}"
    app_name_to_stop = "#{app_name}#{current_color}"

    puts "-- Starting Blue-Green Deployment! --"
    puts "- Will start #{app_name_to_deploy} and stop #{app_name_to_stop} ..."

    # Blue green deployment steps
    # 1) deploy parallel to the route specified in the yml file, check availability
    push(app_name_to_deploy, app_host_to_deploy)

    # 2) map to main route
    map_route(app_name_to_deploy, main_route.host, main_route.domain)

    # 3) unmap other instance from main route
    unmap_route(app_name_to_stop, main_route.host, main_route.domain)

    # 4) stop other instance
    stop_app(app_name_to_stop)

    list_apps
    return true
  end

  #Login to CF
  def login(username, password, endpoint, organization, space)
    #example for login command see ruby syntax for inserting variables into a string
    #for example, #{username} inserts the content of the parameter variable username into the string
    command = "cf login -u #{username} -p #{password} -a #{endpoint} -o #{organization} -s #{space}"
    log_message = "- 0) Logging in to CF #{endpoint}, org #{organization} and space #{space}"

    execute_cf_command(command, log_message)
  end

  #Push an app with manifest
  def push(app_name, app_host)
    #TODO 1: insert push command
    command = "cf push product-list-blue -n product-list-blue"
    log_message = "- 1) Pushing #{app_name}"

    execute_cf_command(command, log_message)
  end

  #Map a route to app_name
  def map_route(app_name, route_host, route_domain)
    #TODO 2: insert command for mapping the route
    command = "cf map-route product-list-blue -n #{route_host} cfapps.sap.hana.ondemand.com"
    log_message = "- 2) Mapping #{app_name} to #{route_host}.#{route_domain}"

    execute_cf_command(command, log_message)
  end

  #Unmap a route to app_name
  def unmap_route(app_name, route_host, route_domain)
    if is_app_bound_to_route?(app_name, Route.new(route_host, route_domain))
      #TODO 3: insert command for unmapping the route
      command = "cf unmap-route product-list -n #{route_host} cfapps.sap.hana.ondemand.com"
      log_message = "- 3) Unmapping #{app_name} from #{route_host}.#{route_domain}"

      execute_cf_command(command, log_message)
    end

  end

  #Stop an app given by app_name
  def stop_app (app_name)
    if is_app_running?(app_name)
      #TODO 4: insert command for stopping the app
      command = "cf stop product-list"
      log_message = "- 4) Stopping #{app_name}"

      execute_cf_command(command, log_message)
    end
  end

  #the constructor
  def initialize(organization, space, endpoint, username, password)
    #stores the space as member variable
    @organization = organization
    @space = space
    @endpoint = endpoint
    @username = username
    @password = password

    puts "-- Preparing blue green deployment in org #{organization} and space #{space}--"
  end

end

# The main entry point for the script execution
def main
  if ARGV.count < 5
    raise "requires parameters <organization> <space> <cf_api_endpoint> <username> <password>"
  end

  organization = ARGV[0]
  space = ARGV[1]
  endpoint = ARGV[2]
  user = ARGV[3]
  password = ARGV[4]

  blueGreenDeployer = BlueGreenDeployer.new organization, space, endpoint, user, password
  blueGreenDeployer.do_blue_green_deployment "product-list"
end

main
