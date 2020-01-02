# TODO: make a mp3 and ogg controller and make them hotswappable
packets = []
if @stream_format[stream["name"]] == "ogg"
file_size = File.size(file_location)
file = File.read(file_location, file_size)

file.split("OggS").each do |c|
    packets.push(c.length + 4)
end
# fist packet is empty
packets.delete_at(0)

open(file_location) do |file|

    # get info packets
    # ex: @conn["piano_packets"] are the info packages for the piano stream
    #   every new stream needs
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
        # TODO: don't read buffer_size on last one, but rather everything there is
        buffer = file.read(buffer_size)

        # TODO: implement cache packet

        @conn[stream["name"]].each do |s|
            Thread.new do
                # sort out closed connections
                if s.closed?
                    puts "session closed"
                    s.close
                    @conn[stream["name"]].delete(s)
                    puts "active streams:s #{@conn[stream["name"]].length}"
                end

                # send buffer to alive connection
                puts buffer.length
            end
        end
        sleep(1)
    end

end
