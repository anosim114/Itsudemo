require "socket"
include Socket::Constants

item_list = [
    # "Jugemo.ogg",
    "Lemon.ogg",
    "A Town With An Ocean View.ogg",
    "Itomori.ogg",
    "Girl who lept through time.ogg",
    "Merry.ogg",
    "Flower Dance.ogg"]

# byte 14 is the page sequence number of an ogg pages
psn = 18

#start new server
server = TCPServer.new("0.0.0.0", 8080)

# array that will hold all current connections
@connections = []

# start new thread to accept new connections
Thread.new do
    while session = server.accept do
        puts "new connection"

        # don't want to send data to favicon, sorry firefox
        req = session.gets || ""
        if req.include? "favicon" 
            session.print "HTTP/1.1 404\r\n\r\n"
            session.close
            next
        end

        # send basic http header
        session.print "HTTP/1.1 200\r\n"
        session.print "content-type: audio/ogg\r\n"
        session.print "cache-control: no-cache, no-store\r\n"
        session.print "expires: Mon, 26 Jul 1997 05:00:00 GMT\r\n"
        session.print "x-content-type-options: nosniff\r\n"
        session.print "server: aaa\r\n"
        session.print "\r\n"
        
        # send first two ogg pages
        # I think they hold information the audio players need?
        # But I'm not certain, since I don't really know ogg well enough
        last_byte = 0
        @info_packets.each do |i|
            session.print i
            # get the page sequence number correctly
            last_byte = i.getbyte(psn)
        end

        # also send one second of cache so that the audio will start playing instantaniously
        buffer = @cache
        # set the right page sequence number here and increment it for later
        buffer.setbyte(psn, last_byte)
        last_byte += 1;

        session.print buffer

        # add new connection to the array
        # :i is the value of the page sequence number
        # it will be set for the current song on each page
        # as soon as the next song starts
        # it is not necessary anymore and I set it to 0 and skip this connection therefore
        @connections.push({"session": session, "i": last_byte})
    end
end

# copy of list of songs
# currently hardcoded, most likely implement it different later
local_list = []
while true do
    # copy global list of files to play if local one is empty
    if local_list.length == 0
        local_list.replace(item_list)
    end

    # get lastest file and delete it from list
    name = local_list.delete_at(0)
    puts "playing: #{name}"

    # read whole file
    file_size = File.size(name)
    file = IO.read(name, file_size)

    # check how big each page is, so that I will read later exactly one page (which is one second)
    packets = []
    file.split("OggS").each do |c|
        packets.push(c.length + 4)
    end

    # first entry is empty, since the file starts with the keyword I use for splitting
    # which produces ["", "data", "data", ...]
    packets.delete_at(0)

    # open the file again and start reading one page at the time
    open(name) do |file|
        # the first two packets in the file are important

        # reset the counter for the page sequence part in an ogg page
        @connections.each do |s|
            if s[:i] != 0 then s[:i] = 0 end
        end

        # get the first two pages, they will be send to new conections
        # since they contain information of the file
        @info_packets = [
            file.read(packets.delete_at(0)),
            file.read(packets.delete_at(0))
        ]

        # send first two pages to all connections
        @info_packets.each do |buffer|
            @connections.each do |c|
                c[:session].print buffer
            end
        end

        # start sending pages, every second
        while packets.length > 0 do
            buffer_size = packets.delete_at(0)
            buffer = file.read(buffer_size)
            @cache = buffer

            puts "header type byte: #{buffer.unpack("AAAAxaxxxxxxxxxxxxC")}"

            @connections.each do |c|
                orig = buffer.getbyte(psn)
                Thread.new do
                    begin
                        if c[:i] > 0
                            buffer.setbyte(psn, c[:i])
                            # puts "#{orig} becomes #{c[:i]}"
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
