#!/usr/bin/env ruby

require 'yaml'

require_relative 'manifest_yaml.rb'

# Helper for BlueGreenDeployment
module BlueGreenHelper

  COLORS = [NONE = '', BLUE = '-blue', GREEN = '-green']

  # Find out if the currently deployed app on given route is blue or green.
  #
  # @param app_name [String] the command to execute on the console
  # @route route [String] the route
  # @return [String] 'blue' or 'green' or raise error if both mapped to route
  def get_deployed_color(app_name, route)
    found_colors = COLORS.select do |color|
      app_name_with_color = "#{app_name}#{color}"
      puts "Looking for app #{app_name_with_color}"
      #is_app_running?(app_name_with_color) && is_app_bound_to_route?(app_name_with_color, route)
      is_app_running_and_bound?(app_name_with_color, route)
    end
    raise "Multiple active apps found #{found_colors}" if found_colors.count > 1
    found_colors = [BLUE] if found_colors.count == 0 #no app deployed, take any color
    found_colors[0]
  end

  # Wrapper that executes a CF command and outputs log messages
  #
  # @param command [String] the command to execute on the console
  # @param log_message [String] the message to be logged
  def get_other_color(color)
    color == BLUE ? GREEN : BLUE
  end

  def select_apps_by_line
    cmd_output = list_apps
    output_lines = cmd_output.split("\n")
    output_lines.select do |line|
      yield(line)
    end
  end

  def is_app_running_and_bound?(app_name, route) #TODO: hier weiter
    found = select_apps_by_line do |line|
      line.start_with?("#{app_name} ") && line.include?('started') && line.include?("#{route}")
    end
    return found.count > 0
  end

  # Checks whether an application is running
  #
  # @param app_name [String] the app name
  # @return [Boolean]
  def is_app_running?(app_name)
    found = select_apps_by_line do |line|
      line.start_with?("#{app_name} ") &&  line.include?('started')
    end
    return found.count > 0
  end

  # Checks whether an application is bound to a given route
  #
  # @param app_name [String] the app name
  # @param route [String] the route to check
  # @return [Boolean]
  def is_app_bound_to_route?(app_name, route)
    found = select_apps_by_line do |line|
      line.start_with?("#{app_name} ") && line.include?("#{route}")
    end
    return found.count > 0
  end

  # Lists all applications within the current space
  #
  # @return [String] cf script execution output
  def list_apps
    execute_command "cf apps"
  end

  # Wrapper that executes a CF command and outputs log messages
  #
  # @param command [String] the command to execute on the console
  # @param log_message [String] the message to be logged
  def execute_cf_command(command, log_message)
    puts "#{log_message} ..."

    begin
      execute_command(command)
    rescue
      raise "#{log_message} - failed"
    end
    puts "#{log_message} - succeeded"
  end

  # Execute a command on the command line via ruby
  #
  # @param cmd_string [String] the command to execute on the console
  # @return [Array] containing boolean with success as first, output string as second (last) element
  def execute_command(cmd_string)
    puts "Executing command: #{cmd_string}"
    output = ""

    io = IO.popen("#{cmd_string}")
    io.each do |line|
      puts line.chomp
      output << line.chomp << "\n"
    end
    io.close
    raise "Executing command: #{cmd_string} failed" unless $?.success?
    return output
  end

  # Returns the main_route as route object
  #
  # @param app_name [String] the name of the app
  # @param space_name [String] the name of the space
  # @param manifest_yml_path [String] Path to the manifest file
  # @return [Route] containing the route (route.host returns the host part, route.domain the domain part)
  def get_main_route(app_name, space_name, manifest_yml_path)
    #loads the manifest as hash (map where the contents are dynamically typed)
    @manifest = ManifestReader.read_manifest_with_parent(manifest_yml_path)

    raise "No application #{app_name} found in manifest.yml" unless @manifest.has_application? app_name
    app_section = @manifest.application(app_name)

    main_domain = app_section['domain']
    raise "No domain set in manifest.yml" if main_domain.nil?

    main_host = app_section['host']
    main_host = "#{app_name}-#{space_name}" if main_host.nil?
    raise "No host set in manifest.yml" if main_host.nil?

    #return main_route as route object
    Route.new(main_host, main_domain)
  end

end
