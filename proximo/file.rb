module Proximo
  class File
    
    F = ::File
    
    def initialize(path)
      @path = path
      @stat = F.stat(path)
    end
    
    def each
      F.open(@path, "rb") do |file|
        while part = file.read(8192)
          yield part
        end
      end
    end
    
    def content_type
      # TODO: combine the mime-type lists of Rack, Mongrel, and Proximo
      # and use that list to lookup mime-type
      Rack::Mime.mime_type(F.extname(@path), 'text/plain')
    end

    def last_modified
      @stat.mtime.httpdate
    end

    def size
      @stat.size.to_s
    end
    
  end
end
