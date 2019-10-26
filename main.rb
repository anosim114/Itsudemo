require "socket"
include Socket::Constants

item_list = [
    "Jugemo.ogg",
    "Lemon.ogg",
    "A Town With An Ocean View.ogg",
    "Itomori.ogg",
    "Girl who lept through time.ogg",
    "Merry.ogg",
    "Flower Dance.ogg"]

# byte 14 is the page sequence number of an ogg pages
psn = 14

server = TCPServer.new 8080

@connections = []

Thread.new do
    while session = server.accept do
        puts "new connection"

        req = session.gets || ""
        if req.include? "favicon" 
            session.print "HTTP/1.1 404\r\n\r\n"
            session.close
            next
        end

        session.print "HTTP/1.1 200\r\n"
        session.print "content-type: audio/ogg\r\n"
        session.print "cache-control: no-cache, no-store\r\n"
        session.print "expires: Mon, 26 Jul 1997 05:00:00 GMT\r\n"
        session.print "x-content-type-options: nosniff\r\n"
        session.print "server: aaa\r\n"
        session.print "\r\n"
        
        puts "sending info"
        last_byte = 0
        @info_packets.each do |i|
            puts "info"
            session.print i
            last_byte = i.getbyte(psn)
        end
        last_byte += 1
        @connections.push({"session": session, "i": last_byte})
    end
end

local_list = []
while true do
    if local_list.length == 0
        local_list.replace(item_list)
    end
    name = local_list.delete_at(0)
    puts "playing: #{name}"
    file_size = File.size(name)

    file = IO.read(name, file_size)
    packets = []
    file.split("OggS").each do |c|
        packets.push(c.length + 4)
    end

    open(name) do |file|
        # the first two packets in the file are important
        @connections.each do |s|
            s[:i] = 0
        end

        @info_packets = [
            file.read(packets.delete_at(0)),
            file.read(packets.delete_at(0)),
            file.read(packets.delete_at(0))
        ]

        @info_packets.each do |buffer|
            @connections.each do |c|
                c[:session].print buffer
            end
        end

        sleep 1
        
        while packets.length > 0 do
            buffer_size = packets.delete_at(0)
            buffer = file.read(buffer_size)

            @connections.each do |c|
                orig = buffer.getbyte(psn)
                Thread.new do
                    begin
                        if c[:i] > 0
                            buffer.setbyte(psn, c[:i])
                            puts "#{orig} becomes #{c[:i]}"
                            c[:i] += 1
                        else
                            buffer.setbyte(psn, orig)
                        end
                        c[:session].print buffer
                    rescue
                        @connections.delete(c)
                        puts "session closed"
                    end
                end
            end
            sleep(1)
        end
    end
end
session.close
