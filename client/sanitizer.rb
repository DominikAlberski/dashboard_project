class Sanitizer
  CSI = %r{\e\[[0-?]*[ -/]*[@-~]}.freeze
  OSC = %r{\e\][^\a\e]*(?:\a|\e\\)?}.freeze

  def self.clean(text)
    strip_control(strip_sequences(text.to_s))
  end

  def self.strip_sequences(text)
    text.gsub(CSI, "").gsub(OSC, "")
  end

  def self.strip_control(text)
    text.each_char.select { |char| keep?(char) }.join
  end

  def self.keep?(char)
    code = char.ord
    return false if code < 0x20 && code != 0x0A
    return false if code == 0x7F
    return false if code >= 0x80 && code <= 0x9F
    true
  end
end
