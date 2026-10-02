require_relative "test_helper"

class InputLineTest < Minitest::Test
  def test_appends_printable_keys
    line = InputLine.new
    line.handle("a")
    line.handle("b")
    assert_equal "ab", line.text
  end

  def test_backspace_removes_last_character
    line = InputLine.new
    line.handle("a")
    line.handle("b")
    line.handle("\b")
    assert_equal "a", line.text
  end

  def test_q_on_empty_line_quits
    assert_equal :quit, InputLine.new.handle("q")
  end

  def test_q_inside_text_does_not_quit
    line = InputLine.new
    line.handle("a")
    assert_nil line.handle("q")
    assert_equal "aq", line.text
  end

  def test_enter_returns_submit
    assert_equal :submit, InputLine.new.handle("\r")
  end

  def test_ctrl_c_returns_quit
    assert_equal :quit, InputLine.new.handle("\u0003")
  end

  def test_clear_empties_the_line
    line = InputLine.new
    line.handle("a")
    line.clear
    assert_equal "", line.text
  end
end
