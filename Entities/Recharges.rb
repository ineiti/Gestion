class Recharges < Entities
  def setup_data
    value_str :time
    value_int :volume
    value_int :days_valid
    value_int :days_goal
  end
end

class Recharge < Entity
  def left_today(left_total)
    end_of_day = (days_goal.to_i - (Date.today - day) - 1) * volume.to_i / days_goal.to_i
    (left_total - (end_of_day < 0 ? 0 : end_of_day)).to_i
  end

  def day
    year, month, day = time.scan(/../)
    Date.new(2000 + year.to_i, month.to_i, day.to_i)
  end

  def self.left_today(left_total)
    if (r = Recharges.search_all_).length > 0
      r.sort { |a, b| a.time <=> b.time }.last.left_today(left_total)
    else
      -1
    end
  end
end