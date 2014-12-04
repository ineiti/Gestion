class Recharges < Entities
  def setup_data
    value_str :time
    value_int :volume
    value_int :days_valid
    value_int :days_goal
  end
end

class Recharge
  def left_today(left_total)
    end_of_day = (days_goal - Date.today + day - 1) * volume / days_goal
    left_total - (end_of_day < 0 ? 0 : end_of_day)
  end

  def day
    year, month, day = time.scan(/../)
    Date.new(2000 + year, month, day)
  end

  def self.left_today(left_total)
    Recharges.search_all_.sort { |a, b| a.time <=> b.time }.last.left_today(left_total)
  end
end