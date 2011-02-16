require 'rack'
require 'net/http'


module Proximo
  class Handler
    attr_accessor :request, :response
    
    F = ::File
    
    def initialize(block, pattern='')
      @block = block
      @pattern = compile(pattern)
    end

    def matches?(string)
      !!(@pattern =~ string)
    end
 
    def execute(request, response)
      # to handle concurrent requests for the same handler in a 
      # threadsafe way, have a clone of this handler service this request
      handler = self.dup
      handler.request = request
      handler.response = response
      handler.instance_eval(&@block)
    end
    

    #---------------------------------------
    # serve (a static file)
    #---------------------------------------

    def serve(file=nil)
      if file.is_a? String
        file = expand_path(file)
      elsif file.is_a? Hash
        file = file[:file]
      else
        file = filepath
      end
      
      # TODO: make this work with:    serve '/something/else'
      #return handle_directory if F.directory?(file)
      
      puts "serve #{F.expand_path(file)}"
      file = Proximo::File.new(file)
      
      response.status = 200
      response['Content-Type'] = file.content_type
      response['Last-Modified'] = file.last_modified
      response['Content-Length'] = file.size.to_s
      response.body = file
    end


    #---------------------------------------
    # fetch (a remote file)
    #---------------------------------------

    def fetch
      http = Net::HTTP.new(remote_host)
      url = request.fullpath
      method = request.request_method

      # forward incoming GET/POST requests to remote host and capture response
      if request.get?
        fetched = http.get(url, headers_for_fetch)
      elsif request.post?
        fetched = http.post(url, form_data, headers_for_fetch)
      end

      # set response status code
      response.status = fetched.code
      
      # set response headers
      # TODO: pass along ALL headers from remote host
      response['Content-Type'] = fetched['Content-Type']
      response['Set-Cookie'] = fetched['Set-Cookie'] unless fetched['Set-Cookie'].nil?
      
      # set response body
      body = fetched.body
      response['Content-Length'] = body.size.to_s
      response.body = body
      
      # logging
      puts "#{method} #{remote_host}#{url}"
      puts "  -> #{form_data}" if request.post?
      puts "  <- #{body.gsub(/\n/, '').strip[0,100]}" if request.post?
    end


    #---------------------------------------
    # DSL methods
    #---------------------------------------

    def echo(body)
      body = body.to_s      
      puts "echo \"#{body}\"" # logging

      response.status = 200
      response['Content-Type'] ||= 'text/html'
      response['Content-Length'] = body.size.to_s
      response.body = body
    end

    def error(code, msg = nil)
      # create default 404 error message
      msg = 'Page not found' if msg.nil? && code == 404

      # create default error HTML page
      body = "<html><title>Error #{code}</title><h1>Error #{code}</h1><h2>#{msg}</h2></html>"

      response.status = code
      response['Content-Type'] = 'text/html'
      response.body = body      
    end

    def directory
      puts "list directory for #{filepath}" # logging
      response.status = 200
      response['Content-Type'] = 'text/html'
      response.body = Rack::Directory.new(root).call(env).last
    end

    def wait(seconds)
      if seconds.is_a?(Range)
        array = seconds.to_a
        seconds = array[rand(array.size)]
      end

      puts "wait for #{seconds} seconds" # logging
      sleep(seconds)
    end

    
    #---------------------------------------
    # request/response getters
    #---------------------------------------
    
    def env
      @env || @env = request.env
    end
    
    def path
      @path || @path = request.path_info
    end

    def filepath
      @filepath || @filepath = expand_path(path)
    end

    def hostname
      @hostname || @hostname = request.host
    end
    
    def host
      @host || @host = Proximo.server.hosts[hostname]
    end

    def root
      @root || @root = host.root
    end
    
    def remote_host
      @remote_host || @remote_host = host.remote_host
    end


  private

    def compile(pattern)
      Regexp.compile('^' + pattern.gsub('*', '(.*)') + '$')
    end
 
    def expand_path(path)
      F.expand_path(F.join(root, Rack::Utils.unescape(path)))
    end

    def headers_for_fetch
      # TODO: pass along ALL headers to remote host
      headers = {}  
      headers['Cookie'] = env['HTTP_COOKIE'] if !request.cookies.empty?
      headers['Content-Type'] = request.content_type if request.post?
      headers
    end
    
    def form_data
      input = env["rack.input"]
      data = input.read
      input.rewind if input.respond_to?(:rewind)
      data
    end

  end
end


# TODO: create default handler only once
module Proximo
  class Handler
    
    def self.default
      # the default behavior for all requests
      default_block = Proc.new do
        if host.nil?          
          error 500,  "Unknown host: #{hostname}"
        elsif F.exists?(filepath)
          if F.directory?(filepath)
            handle_directory
          else
            serve
          end
        else
          if remote_host.nil?
            error 404
          else
            fetch
          end
        end
      end
      
      # return the default handler
      Proximo::Handler.new(default_block)
    end
  
  private

    def handle_directory
      index = find_directory_index
      if !index.nil?        
        serve :file => index
      elsif remote_host.nil?
        directory
      else
        fetch
      end
    end
   
    def find_directory_index
      host.indexes.each do |index|
        index = F.join(filepath, index)
        return index if F.exists?(index)
      end
      nil # no index was found
    end
    
  end
end

