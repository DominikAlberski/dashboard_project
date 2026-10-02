class ViewState
  attr_reader :current

  def initialize
    @current = empty
    @rendered = nil
    @device_label = "starting"
  end

  def apply(event)
    type, value = event
    type == :status ? apply_status(value) : apply_chat(value)
    type == :chat
  end

  def apply_status(payload)
    return set_status(error_text(payload)) if error?(payload)
    show_devices(payload["devices"] || [])
  end

  def error?(payload)
    payload.is_a?(Hash) && payload["error"]
  end

  def error_text(payload)
    "error: #{payload["error"]}"
  end

  def show_devices(devices)
    @device_label = label(devices)
    @current = @current.merge(:devices => devices, :status => @device_label)
  end

  def apply_chat(reply)
    @current = @current.merge(:reply => reply, :thinking => false,
                              :status => @device_label)
  end

  def mark_thinking
    @current = @current.merge(:thinking => true)
  end

  def set_input(text)
    @current = @current.merge(:input => text)
  end

  def set_status(text)
    @current = @current.merge(:status => text)
  end

  def changed?
    @current != @rendered
  end

  def mark_rendered
    @rendered = @current
  end

  def label(devices)
    return "1 device" if devices.size == 1
    "#{devices.size} devices"
  end

  def empty
    { :devices => [], :reply => "", :status => "starting",
      :input => "", :thinking => false }
  end
end
