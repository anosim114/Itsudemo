require "json"
require "uri"
require "socket"

config_raw = File.read("config.json")

config = JSON.parse(config_raw)

@conn = {}
@stream_format = {}
@default = config["default"]
# fist stream is default
config["streams"].each do |s|
    @conn[s["config"]] = []
    @stream_format[s["name"]] = s["format"]
end

# start server on port
puts "starting server on port: #{config["port"]}"
server = TCPServer.new("0.0.0.0", config["port"])

# TODO: rework this whole thing
Thread.new do
    while session = server.accept
        begin
            # Note: set 'success' to true, if a stream for req was found
            # else I will send 404

            req = session.gets "\r\n" || ""

            # TODO: I don't know if this works like that
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

            success = false
            stream = ""
            if url.path == config["base_url"]
                # check if querys were provided
                if query != nil
                    query.each do |q|
                        # check if query with string of stream_param exists
                        if q[0] == config["stream_param"]
                            # check if a stream of that type exists
                            if @conn.key?(q[1])
                                # finally add him to stream
                                @conn[q[1]].push(session)
                                stream = q[1]
                                success = true
                            end
                        end
                    end
                else
                    # put connection into default list
                    stream = @default
                    @conn[@default].push(session)
                    success = true
                end
            end
            
            if success == true
                session.print "HTTP/1.1 200 OK\r\n"
                session.print "Server: blessing/Itsudemo\r\n"
                
                # check format of stream (ogg or mp3)
                if @stream_format[stream] == "mp3"
                    session.print "Content-Type: audio/mpeg\r\n"
                else
                    session.print "Content-Type: audio/ogg\r\n"
                end
                
                session.print "\r\n"
                if @stream_format[stream] == "ogg"
                    @conn["#{stream}_packets"].each do |p|
                        session.print p
                    end
                end

                next
            end
            session.print "HTTP/1.1 404 NOT FOUND\r\n"
                session.print "Server: blessing/Itsudemo\r\n"
                session.print "X-Go-To: https://miona.tk/stream\r\n"
                session.print "\r\n"
            session.close()
        rescue
            next
        end
    end
end

config["streams"].each do |stream|
    stream_config = "#{config["stream_config_location"]}/#{stream["name"]}.json"
    # puts stream_config
    Thread.new do
        # TODO: implement this differently to change playlist on the go
        track_list = []
        while true
            track_list = JSON.parse(File.read(stream_config)) if track_list.length == 0
            name = track_list.delete_at(0)
            file_location = "#{stream["music_location"]}/#{name}"

            # TODO: implement controller here

            if @stream_format[stream["name"]] == "mp3"
                open(file_location) do |file|
                    while (buffer = file.read((1024 * 20) * 3)) != nil

                        # TODO: don't read a buffer iv no one is lisening, rather skip _x_ bytes in file position
                        while @conn[stream["name"]].length == 0
                            sleep 0.2
                        end

                        @conn[stream["name"]].each do |s|
                            Thread.new do
                                begin
                                    # send buffer to alive connection
                                    s.print buffer
                                rescue
                                    # catch thrown exceptoion 
                                    # most likely, broken pipe exception
                                    s.close
                                    @conn[stream["name"]].delete(s)
                                    puts "active streams:s #{@conn[stream["name"]].length}"
                                end
                            end
                        end
                        sleep(3)
                    end
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
