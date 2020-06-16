# Ruby Simple Web Server
# Collin McKinley <collinm@collinm.xyz>

require 'socket'

# Class that represents a client connecting to the web server
class Rsws_client

  def initialize(init_server)
    @server = init_server
    @total = String.new

    @requestHeaders = Hash.new
    @postData = Hash.new

    # Because we want to send all the data at once, setup a buffer so we can
    # simulate using methods like 'puts' without that sending the data before
    # we want to do so
    @buffer = String.new
    @headers = String.new
    
    # Parse the first part of the request, this should look something like
    # `GET / HTTP/1.1`
    # So we can simply split it among spaces to get the information we need
    request = @server.gets.split(" ")
    @method = request[0]
    @path = request[1]
  
    line = " "
    while line != "\r\n"
      line = @server.gets
      if line.include?(":") then
        headerData = line.split(":")
        @requestHeaders[headerData[0].chomp] = headerData[1].chomp
      end
    end
    
    # One last step if we're dealing with POST data
    if @method == "POST" then
      # Try to get the content lenght, otherwise we will hope the client
      # will send us an empty line or something to tell us that we are done reading
      if @requestHeaders["Content-Length"] then
        leftToRead = @requestHeaders["Content-Length"].to_i
      end
    
      vars = @server.read(leftToRead)
      vars_split = vars.split("&")
      vars_split.each do | var |
        data = var.split("=")
        @postData[data[0].chomp] = data[1].chomp
      end
    end

  end

  # Create methods to get our path, method, post data, and request headers
  def path
    return @path
  end
  def method
    return @method
  end

  def headers
    return @requestHeaders
  end

  def get(var)
    if @method != "POST"
      puts "[Rsws] ERROR: Cannot call get unless POST is the current method"
      return 
    end
    return @postData[var]
  end
  def accept

    # Accept simply sends a response that we are ok, really all this is doing
    # is sending the status 200, you could easily do this as well with 
    # `status("200 OK")`
    @headers << "HTTP/1.1 200 OK\r\nServer: Rsws/0.1.0\r\n"
    @accepted = true
  end

  # Allow a cutsom status to be sent if the user doesn't want to send 404 or 200
  def status(stat)
    @headers << "HTTP/1.1 #{stat}\r\n"
    @accepted = true
  end
  
  # Allow a custom content type to be set
  def content_type(type)
    @headers << "Content-Type: #{type}\r\n"
    @content_type = true
  end
  
  # Basically just the anti of accept, allow for 404 messages to be sent
  def not_found
    content_type("text/plain")
    @headers << "HTTP/1.1 404 Not Found\r\nServer: Rsws/0.1.0\r\n"
    puts "#{@method} #{@path} 404 Not Found"
    send
  end
    
  # Read and send in a file
  def send_file(path)

    @buffer = File.read(path)
    send
  end

  # The following print data to the buffer
  def puts(msg)
    @buffer << "#{msg}\n"
  end
  def print(msg)
    @buffer << msg
  end
  def println(msg)
    @buffer << "#{msg}\n"
  end
  
  # When we're finally done, send all the data to the client
  def send
    if @accepted then
      # Calculate content length before sending
    
      @headers << "Content-Length: #{@buffer.length}\r\n"
      
      if !@content_type then
        @headers << "Content-Type: text/html\r\n"
      end

      # Send our data and close the connection
      @server.puts @headers
      @server.puts "\r\n"
      @server.puts @buffer
      @server.close
    else
      puts "[Rsws] ERROR: Trying to send response without first accepting it"
    end
  end
end

# The class of the server
class Rsws
  def initialize(init_port)
    @port = init_port
    @server = TCPServer.new @port
  end
 
  # Where most of the logic happens
  def run
    loop do
      client_sock = @server.accept
      client = Rsws_client.new(client_sock)
      yield client
    end
  end
end
