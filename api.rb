require 'bundler/setup'
%w(yaml json digest redis csv).each { |req| require req }
Bundler.require(:default)
require 'sinatra'
require_relative 'funs'
require_relative 'models/models'

# feature flag: toggle redis
$use_redis = false

# api key
$api_key = ENV['BIEN_API_KEY']

$config = YAML::load_file(File.join(__dir__, ENV['RACK_ENV'] == 'test' ? 'test_config.yaml' : 'config.yaml'))

$redis = Redis.new host: ENV.fetch('REDIS_PORT_6379_TCP_ADDR', 'localhost'),
                   port: ENV.fetch('REDIS_PORT_6379_TCP_PORT', 6379)

ActiveSupport::Deprecation.silenced = true
ActiveRecord::Base.establish_connection($config['db'])
ActiveRecord::Base.logger = Logger.new(STDOUT)

class API < Sinatra::Application
  configure do
    # Don't log them. We'll do that ourself
    set :dump_errors, true

    # Don't capture any errors. Throw them up the stack
    set :raise_errors, true

    # Disable internal middleware for presenting errors
    # as useful HTML pages
    set :show_exceptions, true
  end

  before do
    puts '[env]'
    p env
    puts '[Params]'
    p params

    $route = request.path

    # set headers
    headers 'Content-Type' => 'application/json; charset=utf8'
    headers 'Access-Control-Allow-Methods' => 'HEAD, GET'
    headers 'Access-Control-Allow-Origin' => '*'
    cache_control :public, :must_revalidate, max_age: 60

    # prevent certain verbs
    if request.request_method != 'GET'
      halt 405
    end

    # use redis caching
    if $config['caching'] && $use_redis
      if request.path_info != "/"
        @cache_key = Digest::MD5.hexdigest(request.url)
        if $redis.exists(@cache_key)
          headers 'Cache-Hit' => 'true'
          halt 200, $redis.get(@cache_key)
        end
      end
    end

  end

  before do
    pass if %w[/ /heartbeat /heartbeat/].include? request.path_info
    halt 401, { error: 'not authorized' }.to_json unless valid_key?(request.env['HTTP_AUTHORIZATION'])
  end

  after do
    # cache response in redis
    if $config['caching'] &&
      $use_redis &&
      !response.headers['Cache-Hit'] &&
      response.status == 200 &&
      request.path_info != "/" &&
      request.path_info != ""

      $redis.set(@cache_key, response.body[0], ex: $config['caching']['expires'])
    end
  end

  helpers do
    def valid_key?(key)
      key == $api_key
    end

    def serve_data(ha, data)
      # puts '[CONTENT_TYPE]'
      # puts request.env['CONTENT_TYPE'].nil?
      case request.env['CONTENT_TYPE']
      when 'application/json'
        ha.to_json
      when 'text/csv'
        to_csv(data)
      when nil
        ha.to_json
      else
        halt 415, { error: 'Unsupported media type', message: 'supported media types are application/json and text/csv; no Content-type equals application/json' }.to_json
      end
    end
  end

  configure do
    mime_type :apidocs, 'text/html'
    mime_type :csv, 'text/csv'
  end

  # handle missed route
  not_found do
    halt 404, { error: 'route not found' }.to_json
  end

  # handle other errors
  error do
    halt 500, { error: 'server error' }.to_json
  end

  # handler - redirects any /foo -> /foo/
  #  - if has any query params, passes to handler as before
  # get %r{(/.*[^\/])$} do
  #   if request.query_string == "" or request.query_string.nil?
  #     redirect request.script_name + "#{params[:captures].first}/"
  #   else
  #     pass
  #   end
  # end

  # default to landing page
  ## used to go to /heartbeat
  get '/?' do
    content_type :apidocs
    send_file File.join(settings.public_folder, '/index.html')
  end

  # route listing route
  get '/heartbeat/?' do
    db_routes = Models.models.map do |m|
      "/#{m.downcase}#{Models.const_get(m).primary_key ? '/:id' : '' }?<params>"
    end
    { routes: %w( /heartbeat /list /list/country /plot/metadata /plot/protocols /traits/ /traits/family ) + db_routes }.to_json
  end

  # generate routes from the models
  Models.models.each do |model_name|
    model = Models.const_get(model_name)
    get "/#{model_name.to_s.downcase}/?#{model.primary_key ? ':id?/?' : '' }" do
      begin
        data = model.endpoint(params)
        raise Exception.new('no results found') if data.length.zero?
        ha = { count: data.limit(nil).count(1), returned: data.length, data: data, error: nil }
        serve_data(ha, data)
      rescue Exception => e
        halt 400, { count: 0, returned: 0, data: nil, error: { message: e.message }}.to_json
      end
    end
  end

  get '/list/?' do
    begin
      data = List.endpoint(params)
      raise Exception.new('no results found') if data.length.zero?
      ha = { count: data.limit(nil).count(1), returned: data.length, data: data, error: nil }
      serve_data(ha, data)
    rescue Exception => e
      halt 400, { count: 0, returned: 0, data: nil, error: { message: e.message }}.to_json
    end
  end

  get '/list/country/?' do
    begin
      data = ListCountry.endpoint(params)
      raise Exception.new('no results found') if data.length.zero?
      ha = { count: data.limit(nil).count(1), returned: data.length, data: data, error: nil }
      serve_data(ha, data)
    rescue Exception => e
      halt 400, { count: 0, returned: 0, data: nil, error: { message: e.message }}.to_json
    end
  end


  # plot routes
  get '/plot/metadata/?' do
    begin
      data = PlotMetadata.endpoint(params)
      raise Exception.new('no results found') if data.length.zero?
      ha = { count: data.limit(nil).count(1), returned: data.length, data: data, error: nil }
      serve_data(ha, data)
    rescue Exception => e
      halt 400, { count: 0, returned: 0, data: nil, error: { message: e.message }}.to_json
    end
  end

  ## List available sampling protocols
  get '/plot/protocols/?' do
    begin
      data = PlotProtocols.endpoint(params)
      raise Exception.new('no results found') if data.length.zero?
      ha = { count: data.limit(nil).count(1), returned: data.length, data: data, error: nil }
      serve_data(ha, data)
    rescue Exception => e
      halt 400, { count: 0, returned: 0, data: nil, error: { message: e.message }}.to_json
    end
  end

  # trait routes
  ## all traits
  get '/traits/?' do
    begin
      data = Traits.endpoint(params)
      raise Exception.new('no results found') if data.length.zero?
      ha = { count: data.limit(nil).count(1), returned: data.length, data: data, error: nil }
      serve_data(ha, data)
    rescue Exception => e
      halt 400, { count: 0, returned: 0, data: nil, error: { message: e.message }}.to_json
    end
  end

  ## traits by family
  get '/traits/family/?' do
    begin
      data = TraitsFamily.endpoint(params)
      raise Exception.new('no results found') if data.length.zero?
      ha = { count: data.limit(nil).count(1), returned: data.length, data: data, error: nil }
      serve_data(ha, data)
    rescue Exception => e
      halt 400, { count: 0, returned: 0, data: nil, error: { message: e.message }}.to_json
    end
  end

  # occurrence routes
  ## species
  get '/occurrence/species/?' do
    begin
      data = OccurrenceSpecies.endpoint(params)
      raise Exception.new('no results found') if data.length.zero?
      ha = { count: data.limit(nil).count(1), returned: data.length, data: data, error: nil }
      serve_data(ha, data)
    rescue Exception => e
      halt 400, { count: 0, returned: 0, data: nil, error: { message: e.message }}.to_json
    end
  end


  # taxonomy routes
  ## by species
  # get '/taxonomy/species/?' do
  #   begin
  #     data = TaxonomySpecies.endpoint(params)
  #     raise Exception.new('no results found') if data.length.zero?
  #     ha = { count: data.limit(nil).count(1), returned: data.length, data: data, error: nil }
  #     serve_data(ha, data)
  #   rescue Exception => e
  #     halt 400, { count: 0, returned: 0, data: nil, error: { message: e.message }}.to_json
  #   end
  # end

end
