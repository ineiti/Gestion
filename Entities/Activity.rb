class Activities < Entities

  PAYMENTS = %w( daily weekly monthly yearly )
  START = %w( payment period period_overlap )

  def setup_data
    value_str :name

    value_block :show
    value_str :description
    value_int :cost
    value_list_drop :payment_period, 'Activities::PAYMENTS'
    value_list_drop :start_type, 'Activities::START'
    value_int :overlap

    value_block :hidden
    value_str :card_filename
  end

  def files
    Dir.glob(get_config('.', :Entities, :Courses, :dir_diplomas) + '/*.{ods,odg}').
        collect { |f| f.cut(/^.*\//) }
  end

  def active_for(s, d = Date.today)
    ActivityPayments.search_by_person_paid(s).select { |ap|
      ap.date_start <= d and d <= ap.date_end
    }.collect{|ap| ap.activity}
  end

end

class Activity < Entity
  def start_end( s, d = Date.today )
    ActivityPayments.search_by_person_paid(s).select { |ap|
      ap.date_start <= d and d <= ap.date_end and ap.activity == self
    }.collect{|ap| [ap.date_start, ap.date_end]}.pop || [nil, nil]
  end
end

class ActivityPayments < Entities
  def setup_data
    value_entity_activity :activity
    value_entity_person :person_paid
    value_entity_person :person_cashed
    value_entity_movement :movement
    value_date :date_start
    value_date :date_end
  end

  def week_start(date)
    date - date.cwday
  end

  def get_one_period(date, period, ceil = false)
    [date,
     case period.to_s
       when /day/
         date + 1
       when /week/
         (ceil ? week_start(date) + 7 : date) + 7
       when /month/
         (ceil ? Date.new(date.year, date.month + 1) : date).next_month
       when /year/
         (ceil ? Date.new(date.year + 1) : date).next_year
     end - 1]
  end

  # Get start and end of a period respecting overlap lesser periods before
  def get_period(date, period, overlap=0)
    case period.to_s
      when /day/
        return [date - overlap, date]
      when /week/
        ceil = (date + overlap >= week_start(date) + 7)
        start = ceil ? date : week_start(date)
      when /month/
        ceil = (date + overlap * 7 >= Date.new(date.year, date.month + 1))
        start = ceil ? date : Date.new(date.year, date.month)
      when /year/
        ceil = (date.next_month(overlap) >= Date.new(date.year + 1))
        start = ceil ? date : Date.new(date.year)
    end
    get_one_period(start, period, ceil)
  end

  def pay(act, p_paid, p_cashed, d_today = Date.today)
    mov = Movements.create("#{p_paid.login_name} paid #{p_cashed.login_name} #{act.cost} "+
                               "for #{act.name}", Date.today, act.cost,
                           p_cashed.account_due, ConfigBase.account_activities)
    date_start, date_end =
        case act.start_type.to_s
          when /payment/
            get_one_period(d_today, act.payment_period)
          when /period/, /period_overlap/
            get_period(d_today, act.payment_period, act.overlap.to_i)
        end
    ActivityPayments.create(activity: act, person_paid: p_paid, person_cashed: p_cashed,
                            movement: mov, date_start: date_start, date_end: date_end)
  end
end
