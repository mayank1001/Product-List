require 'yaml'

class ManifestYaml
  def initialize(manifest_content, manifest_base = nil)
    @manifest_content = manifest_content
    @manifest_inherit = manifest_base
  end

  def find (readValue)
    value = readValue.call(@manifest_content)
    value = @manifest_inherit.find readValue if value.nil? unless @manifest_inherit.nil?
    return value
  end

  def get (option_name)
    getter = lambda { |manifest_content| manifest_content[option_name]}
    find (getter)
  end

  def applications
    applications = @manifest_inherit.applications unless @manifest_inherit.nil?
    applications = [] if  @manifest_inherit.nil?

    applications += @manifest_content["applications"].collect {|application| HashWithDefaults.new(application, self)} unless @manifest_content["applications"].nil?

    raise_on_duplicate_names(applications)
    applications
  end
  
  def has_application?(app_name)
    applications().select{|app| app['name'] == app_name}.length >= 1
  end

  def application(app_name)
    apps_with_name = applications().select{|app| app['name'] == app_name}
    raise "No app with name #{app_name} found in manifest.yml" unless apps_with_name.length > 0
    raise "Multiple apps with name #{app_name} found in manifest.yml" if apps_with_name.length > 1
    apps_with_name.first
  end

  # CF manifest behaviour, if only a single application is found in manifest, it will be deployed under a different app_name
  def single_application_or_by_name(app_name)
    if(applications.length == 1)
      manifest_app_part = applications.first
    else
      manifest_app_part = application(app_name)
    end
    manifest_app_part
  end

  def get_hash
    return @manifest_content
  end

  def get_parent
    return @manifest_inherit
  end

  def get_merged_hashes
    hash = @manifest_inherit.get_merged_hashes() unless @manifest_inherit.nil?
    hash = {} if @manifest_inherit.nil?
    hash.merge get_hash
  end

  def raise_on_duplicate_names(array_of_hashes)
    names = array_of_hashes.collect{|app| app['name']}
    names.sort!
    for i in 0..names.length-1
      for j in i+1..names.length-1
        raise "Duplicate name #{names[i]} and #{names[j]}" if names[i] == names[j]
      end
    end
  end
end

class HashWithDefaults
  def initialize(hash, default_from)
    @hash = hash
    @default_from = default_from
  end

  def [](parameter)
    return_value = @hash[parameter]
    return_value = @default_from.get(parameter) if return_value.nil?
    return_value
  end

  def inspect
    @default_from.get_merged_hashes().merge(@hash).inspect
  end
end

class ManifestReader
  def self.read_manifest_with_parent (yaml_file)
    @yaml_content = read_manifest_as_hash(yaml_file)
    ManifestYaml.new @yaml_content, self.get_base_manifest(@yaml_content, File.dirname(yaml_file))
  end

  # Reads a manifest yaml from the fiven file path
  #
  # @param manifest_file_path [String] the full file path to a manifest.yml
  # @return [Hash] a hash with the contents of the manifest file
  def self.read_manifest_as_hash(manifest_file_path)
    path = File.expand_path manifest_file_path
    YAML.load_file(path)
  rescue => err
    raise "Couldn't load manifest file from #{manifest_file_path} #{err}"
  end

  private

  def self.get_base_manifest (manifest_content, directory)
    return nil if manifest_content['inherit'].nil?
    expected_file = File.join(directory, manifest_content['inherit'])
    return read_manifest_with_parent(expected_file)
  end

end
