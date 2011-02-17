# Proximo : a tiny proxy server based on Sinatra
#
# expects settings file (proximo.yml) in same directory, in this format:
#
#   local.domain.com:
#     aliases:
#       - local.alias.com
#       - other.local.alias.com
#     docroot: C:\local\static\files
#     remote_host: www.domain.com
#     always_from_remote:
#       - /filename.html
#       - leading/slash/is-optional.css
#       - /can/use/*/wildcards/*.jsp

require 'net/http'
require 'rubygems'
require 'sinatra'
require 'yaml'


# listen on default HTTP port, so simple hostnames can be used
set :port, 80

# do not automatically serve local files (all requests go through get/post handlers)
set :static, false



# read from settings file before handling each request (no restarts required)
before do
  host = request.host
  @settings = settings_for(host)
  fail "Settings not defined for hostname '#{host}'." if @settings.nil?

  # tell Sinatra where to find local static files
  docroot = @settings['docroot']
  fail "docroot not defined for hostname '#{host}'." if docroot.nil?
  fail "Docroot '#{docroot}' does not exist." if !File.exists?(docroot)
  set :public, docroot

  @remote_host = @settings['remote_host']
  #fail "remote_host not defined for hostname '#{host}'." if @remote_host.nil?

  # if the requested path ends in a slash, and an index.html is available in a local 
  # folder with that name, explicitly append 'index.html' to the path
  # otherwise, it is fetched from remote server (which routes to index.html, index.jsp, etc.)
  path = request.path_info  
  path << 'index.html' if ends_with_slash?(path) && exists_locally?(path + 'index.html')
  @path = path
end

# delegate all GET/POST requests to custom handlers
get '*' do 
  if serve_local?
    serve_local
  else
    serve_remote
  end
end

post '*' do
  if serve_local?
    serve_local
  else
    serve_remote
  end
end



#----------------------------------------------------------------------
# HTTP handlers (local and remote)
#----------------------------------------------------------------------

# rules for which resources are to be served from local filesystem
def serve_local?
  # serve local files if no remote host was defined
  return true if @remote_host.nil?
  
  # otherwise, serve local files if all of the following are true
  !matches_any?(@path, @settings['always_from_remote']) &&  # path does not match an 'always_from_remote' pattern
  exists_locally?(@path) &&                                 # path exists on local filesystem
  !ends_with_slash?(@path)                                  # path is not a directory (forces fetch of remote 
end                                                         #   directory indexes such as index.jsp)

def serve_local
  send_file(File.expand_path(options.public + unescape(@path)))
end

def serve_remote
  http = Net::HTTP.new(@remote_host)
  path = @path + '?' + request.query_string

  # forward incoming GET/POST requests to remote host and capture response
  if request.get?
    remote = http.get(path, custom_headers)
  elsif request.post?
    remote = http.post(path, form_data, custom_headers)
  end

  # set HTTP response headers based on remote host's response
  status remote.code
  content_type remote['content-type']
  response['Set-Cookie'] = remote['Set-Cookie'] if !remote['Set-Cookie'].nil?

  # return body of remote host's response (to be served by get/post handlers)
  remote.body
end

def custom_headers
  headers = {}  
  headers['Cookie'] = @env['HTTP_COOKIE'] if !request.cookies.empty?
  headers['Content-Type'] = request.content_type if request.post?
  headers
end

def form_data
  @env['rack.request.form_vars'] || ''
end



#----------------------------------------------------------------------
# utility functions
#----------------------------------------------------------------------

def settings_for(hostname)
  # look up settings for the requested hostname in YAML file
  yaml = File.join(File.dirname(__FILE__), 'proximo.yml')
  settings = YAML.load(File.open(yaml))
  return settings[hostname] unless settings[hostname].nil?
  
  # search aliases for the requested hostname
  settings.values.each do |opts|
    if opts.has_key? 'aliases'
      if opts['aliases'].any? { |host_alias| host_alias == hostname }
        return opts
      end
    end
  end
  
  nil
end

def ends_with_slash?(path)
  path =~ /\/$/
end

def exists_locally?(path)
  File.exists?(File.join(options.public, path))
end

def matches_any?(path, patterns)
  return false if patterns.nil?
  patterns.any? { |pattern| to_regexp(pattern) =~ path }
end

def to_regexp(string)  
  # convert string pattern to regular expression
  # - replace * wildcard with regex wildcard
  # - surround pattern with ^ and $ anchors
  # - make leading slash optional
  Regexp.compile('^\/?' + string.gsub('*', '(.*)') + '$')
end
