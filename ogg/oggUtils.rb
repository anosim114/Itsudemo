def ogg_frames(stream)
    pages = []
    file = stream.read(stream.size)

    file.split("OggS").each do |chunk|
        # +4 to get the OggS size back in
        pages.push(chunk.length + 4)
    end

    # fist packet is empty
    pages.delete_at(0)

    stream.rewind
    return pages
end
