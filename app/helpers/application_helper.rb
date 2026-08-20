module ApplicationHelper
  # Returns a human-readable label for a date relative to today.
  #   today      → "Today"
  #   yesterday  → "Yesterday"
  #   older      → "Monday, Aug 18"
  def event_date_label(date)
    if date == Date.current
      "Today"
    elsif date == Date.current - 1
      "Yesterday"
    else
      date.strftime("%A, %b %-d")
    end
  end
end
