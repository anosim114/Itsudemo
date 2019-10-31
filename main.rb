require "json"
require "uri"
require "socket"

config_raw = File.read("config.json")

config = JSON.parse(config_raw)

@conn = {}
@default = config["default"]

# fist stream is default
config["streams"].each do |s|
    @conn[s["name"]] = []
end

# start server on port
puts "starting server on port: #{config["port"]}"
server = TCPServer.new("0.0.0.0", config["port"])

Thread.new do
    while session = server.accept do
        puts "\n----- NEW USER -----"
        # test_uri.each do |uri|

        # Note: set 'success' to true, if a stream for req was found
        # else I will send 404

        req = session.gets "\r\n" || ""

        # TODO: I don't know if this works like that
        puts req
        if req == ""
            session.print "HTTP/1.1 404 NOT FOUND\r\n\r\n"
            session.close()
            next
        end

        if !(req.include? " ")
            session.print "HTTP/1.1 404 NOT FOUND\r\n\r\n"
            session.close()
            next
        end

        # TODO: any better way?
        url = URI(req.split(" ")[1])

        query = nil
        if url.query != nil
            query = URI.decode_www_form(url.query)
        end
        puts url.to_s

        success = false
        stream = ""
        if url.path == config["base_url"]
            # check if the user wants a specific stream
            # check if querys were provided
            if query != nil
                query.each do |q|
                    # check if query with string of stream_param exists
                    if q[0] == config["stream_param"]
                        # check if a stream of that type exists
                        if @conn.key?(q[1])
                            # finally add him to stream
                            puts "adding to stream '#{q[1]}'"
                            @conn[q[1]].push(session)
                            stream = q[1]
                            success = true
                        end
                    end
                end
            else
                # put connection into default list
                puts "default: adding to stream"
                stream = @default
                @conn[@default].push(session)
                success = true
            end
        end
        
        # TODO: info packets
        if success == true
            session.print "HTTP/1.1 404 NOT FOUND\r\n"
            session.print "Server: blessing/vItsudemo\r\n"
            session.print "Content-Type: audio/ogg\r\n"
            
            session.print "\r\n"
            @conn["#{stream}_packets"].each do |p|
                session.print p
            end

            next
        end
        puts "send 404"
        session.print "HTTP/1.1 404 NOT FOUND\r\n\r\n"
        session.close()
    end
end

config["streams"].each do |stream|
    stream_config = "#{config["stream_config_location"]}#{stream["name"]}.json"
    puts stream_config
    Thread.new do
        track_list = []
        while true do
            track_list = JSON.parse(File.read(stream_config)) if track_list.length == 0
            name = track_list.delete_at(0)
            file_location = "#{config["music_location"]}/#{name}"

            puts "> #{stream["name"]} playing: #{name}"

            file_size = File.size(file_location)
            file = File.read(file_location, file_size)

            packets = []
            file.split("OggS").each do |c|
                packets.push(c.length + 4)
            end
            # fist packet is empty
            packets.delete_at(0)

            open(file_location) do |file|

                # get info packets
                @conn["#{stream["name"]}_packets"] = [
                    file.read(packets.delete_at(0)),
                    file.read(packets.delete_at(0))
                ]

                # send info packets
                @conn["#{stream["name"]}_packets"].each do |buffer|
                    @conn[stream["name"]].each do |s|
                        s.print buffer
                    end
                end

                # send other packets
                while packets.length > 0 do
                    buffer_size = packets.delete_at(0)
                    buffer = file.read(buffer_size)

                    # TODO: implement cache packet
        
                    @conn[stream["name"]].each do |s|
                        Thread.new do
                            begin
                                s.print buffer
                            rescue
                                puts "session errored"
                                s.close
                                @conn[stream["name"]].delete(s)
                            end
                        end
                    end
                    sleep(1)
                end
                
            end
        end
    end
end

# set api variables
# like: current_listeners and so on
while true
    sleep 100
end
