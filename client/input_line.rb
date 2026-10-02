class InputLine
  attr_reader :text

  def initialize
    @text = ""
  end

  def handle(key)
    return :quit if quit?(key)
    return :submit if enter?(key)
    edit(key)
    nil
  end

  def clear
    @text = ""
  end

  def quit?(key)
    key == "\u0003" || (key == "q" && @text.empty?)
  end

  def enter?(key)
    key == "\r" || key == "\n"
  end

  def edit(key)
    return if backspace?(key) && remove
    append(key)
  end

  def backspace?(key)
    key == "\b" || key == "\u007F"
  end

  def remove
    return false if @text.empty?
    @text = @text[0...-1]
    true
  end

  def append(key)
    return unless printable?(key)
    @text += key
  end

  def printable?(key)
    key.ord >= 0x20 && key.ord != 0x7F
  end
end
