class Route 
  attr_reader :host, :domain
  
  def initialize(host, domain) 
    @host = host
    @domain = domain
  end
  
  def to_s
    "#{@host}.#{@domain}"
  end
end
