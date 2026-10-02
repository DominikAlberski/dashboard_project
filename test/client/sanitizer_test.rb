require_relative "test_helper"

class SanitizerTest < Minitest::Test
  def test_removes_escape
    assert_equal "ab", Sanitizer.clean("a\eb")
  end

  def test_removes_c0_except_newline
    assert_equal "a\nb", Sanitizer.clean("a\x00\x01\x1f\nb")
  end

  def test_removes_del
    assert_equal "ab", Sanitizer.clean("a\x7fb")
  end

  def test_removes_c1
    assert_equal "ab", Sanitizer.clean("a\u0080\u009fb")
  end

  def test_keeps_printable_text
    assert_equal "hello world", Sanitizer.clean("hello world")
  end
end
