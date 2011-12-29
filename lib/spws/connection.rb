class Viewpoint::SPWS::Connection
  include Viewpoint::SPWS

  # @param [String] site_base the base URL of the site not including the
  #   web service part.
  #   @example https://<site>/personal/myname
  def initialize(site_base)
    @log = Logging.logger[self.class.name.to_s.to_sym]
    @httpcli = HTTPClient.new
    site_base = site_base.end_with?('/') ? site_base : site_base << '/'
    @site_base = URI.parse(site_base)
  end

  def set_auth(user,pass)
    @httpcli.set_auth(@site_base.to_s, user, pass)
  end

  def lists_ws
    Lists.new(self)
  end

  def usergroup_ws
    UserGroup.new(self)
  end

  # Authenticate to the web service
  # @return [Boolean] true if authentication is successful, false otherwise
  def authenticate(websvc)
    self.get(websvc) && true
  end

  # Send a GET to the web service
  # @return [String] If the request is successful (200) it returns the body of
  #   the response.
  def get(websvc)
    check_response( @httpcli.get(@site_base + websvc) )
  end

  # Send a POST to the web service
  # @return [String] If the request is successful (200) it returns the body of
  #   the response.
  def post(websvc, xmldoc)
    headers = {'Content-Type' => 'application/soap+xml; charset=utf-8'}
    url = (@site_base + websvc).to_s
    check_response( @httpcli.post(url, xmldoc, headers) )
  end


  private

  def check_response(resp)
    case resp.status
    when 200
      resp.body
    when 500
      if resp.headers['Content-Type'].include?('xml')
        err_string, err_code = parse_soap_error(resp.body)
        raise "SOAP Error: Message: #{err_string}  Code: #{err_code}"
      else
        raise "Internal Server Error. Message: #{resp.body}"
      end
    else
      raise "HTTP Error Code: #{resp.status}, Msg: #{resp.body}"
    end
  end

  # @param [String] xml to parse the errors from.
  def parse_soap_error(xml)
    ndoc = Nokogiri::XML(xml)
    ns = ndoc.collect_namespaces
    err_string  = ndoc.xpath("//xmlns:errorstring",ns).text
    err_code    = ndoc.xpath("//xmlns:errorcode",ns).text
    @log.debug "Internal SOAP error. Message: #{err_string}, Code: #{err_code}"
    [err_string, err_code]
  end

end