require "socket"

item_list = []

server = TCPServer.new 5678

session = server.accept
request = session.gets
puts request
puts "new session"

session.print "HTTP/1.1 200\r\n"
# session.print "Content-Type: audio/ogg\r\n"
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
        session.print file.read(packets.delete_at(0))
        session.print file.read(packets.delete_at(0))
        
        while packets.length > 0 do
            buffer_size = packets.delete_at(0)
            session.print file.read(buffer_size)
            sleep(1)
        end
    end
end
session.close
