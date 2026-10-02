class Sanitizer
  def self.clean(text)
    text.to_s.each_char.select { |char| keep?(char) }.join
  end

  def self.keep?(char)
    code = char.ord
    return false if code < 0x20 && code != 0x0A
    return false if code == 0x7F
    return false if code >= 0x80 && code <= 0x9F
    true
  end
end
