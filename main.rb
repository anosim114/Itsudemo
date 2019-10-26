require "socket"

item_list = [
    "Itomori.ogg",
    "Lemon.ogg",
    "A Town With An Ocean View.ogg",
    "Girl who lept through time.ogg",
    "Merry.ogg",
    "Flower Dance.ogg"]

server = TCPServer.new 5678

@connections = []

session = server.accept
@connections.push({"session": session, "i": 6})
session.print "HTTP/1.1 200\r\n"
session.print "content-type: audio/ogg\r\n"
session.print "cache-control: no-cache, no-store\r\n"
session.print "expires: Mon, 26 Jul 1997 05:00:00 GMT\r\n"
session.print "x-content-type-options: nosniff\r\n"
session.print "server: aaa\r\n"
session.print "\r\n"

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
            file.read(packets.delete_at(0))
        ]

        @info_packets.each do |i|
            session.print i
        end

        # have a small cache of 5 seconds to send to the clients
        @cache = [
            file.read(packets.delete_at(0)),
            file.read(packets.delete_at(0)),
            file.read(packets.delete_at(0)),
            file.read(packets.delete_at(0)),
            file.read(packets.delete_at(0))
        ]
        
        @cache.each do |c|
            session.print(c)
        end

        while packets.length > 0 do
            buffer_size = packets.delete_at(0)
            buffer = file.read(buffer_size)

            @cache.push(buffer)
            @cache.shift()

            # byte 14 is the page sequence number of an ogg pages
            psn = 14
            @connections.each do |s|
                if s[:i] > 0
                    buffer.setbyte(psn, s[:i])
                    s[:i] += 1
                end
            end
            session.print buffer
            sleep(1)
        end
    end
end
session.close
