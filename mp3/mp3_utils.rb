# https://github.com/kobsy/framy_mp3/blob/master/lib/framy_mp3/file.rb
require_relative "frames"

def mp3_frame_header(buffer)
    Frame.new(buffer)
end

def mp3_frames(file)

    frame = nil
    frame_start = 0
    frames = []

    buffer = file.read(4).unpack("C*")

    loop do
        tag_v1 = ""
        tag_v2 = ""

        if buffer[0] == 84 && buffer[1] == 65 && buffer[2] == 71 # TAG
            tag_v1 << buffer.pack("C*")
            tag_v1 << file.read(124)

        elsif buffer[0] == 73 && buffer[1] == 68 && buffer[2] == 51 # ID3
            tag_v2 = buffer.pack("C*")
            tag_v2 << file.read(2)
            tag_v2 << size = file.read(4)
            size_bytes = size.unpack("C*")
            
            # 0xxxxxxx 0xxxxxxx 0xxxxxxx 0xxxxxxx
            # the first bit of a byte is unused
            # so 257 != 00000001 00000001, but 00000010 00000001
            tag_length =
                (size_bytes[0] << 21) +
                (size_bytes[1] << 14) +
                (size_bytes[2] << 7) +
                (size_bytes[3])

            tag_v2 << file.read(tag_length)

        elsif buffer[0] == 255 && (buffer[1] & 0b11110000) == 0b11110000
            frame_start = file.pos
            frame = Frame.new(buffer)
            # frames << frame.length
            
            # NOTE: break at first 
            break
            file.read(frame.length - 4)
        end

        # Nothing found. Shift the buffer forward by one byte and try again.
        buffer.shift
        next_byte = file.read(1)&.unpack("C")&.first
        break if next_byte.nil?
        buffer << next_byte
    end
    
    file.rewind
    return {bitrate: frame.bitrate, start_pos: frame_start}
end
