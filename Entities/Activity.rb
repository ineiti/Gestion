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
    value_list :tags, '%w( library internet club )'
  end

  def files
    ConfigBase.templates.collect { |f| f.cut(/^.*\//) }
  end

  def tagged(*tags)
    tags.inspect
    Activities.search_all_.select { |a|
      (tags - a.tags).length == 0
    }
  end

  def tagged_users(tags, date = Date.today)
    #dputs_func
    tagged(tags).collect { |a|
      aps = ActivityPayments.search_by_activity( a )
      dputs(3){"Found #{aps.inspect} for tag #{a}"}
      ActivityPayments.active_now( aps, date ).collect{|ap|
        dputs(3){"Found #{ap.inspect} active for now"}
        ap.person_paid
      }
    }.flatten.uniq
  end
end


class Activity < Entity
  attr_accessor :print_card

  def setup_instance
    ddir = Courses.dir_diplomas
    adir = "#{ddir}/Activities"
    if !File.exist? adir
      FileUtils::mkdir(adir)
    end
    @print_card = OpenPrint.new(card_filename, adir)
  end

  def start_end(s, d = Date.today)
    ActivityPayments.search_by_person_paid(s).select { |ap|
      ap.date_start <= d and d <= ap.date_end and ap.activity == self
    }.collect { |ap| [ap.date_start, ap.date_end] }.pop || [nil, nil]
  end

  def card_filename
    "#{get_config('.', :Entities, :Courses, :dir_diplomas)}/#{self._card_filename.first}"
  end

  def cost_mov
    self._cost.to_i / 1000.0
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

  def self.week_start(date)
    date - date.cwday
  end

  def self.get_one_period(date, period, ceil = false)
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
  def self.get_period(date, period, overlap=0)
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

  def self.pay(act, p_paid, p_cashed, d_today = Date.today)
    mov = Movements.create("#{p_paid.login_name} paid #{p_cashed.login_name} #{act.cost} "+
                               "for #{act.name}", Date.today, act.cost_mov,
                           p_cashed.account_due, ConfigBase.account_activities)
    date_start, date_end =
        case act.start_type.to_s
          when /payment/
            get_one_period(d_today, act.payment_period)
          when /period/, /period_overlap/
            get_period(d_today, act.payment_period, act.overlap.to_i)
        end

    log_msg :ActivityPayments, "#{date_start} - #{date_end}: #{mov.inspect}"
    ActivityPayments.create(activity: act, person_paid: p_paid, person_cashed: p_cashed,
                            movement: mov, date_start: date_start, date_end: date_end)
  end

  def self.active_now(actp, d = Date.today)
    return [] unless actp
    actp.select { |ap|
      ap.date_start <= d and d <= ap.date_end
    }
  end

  def self.active_for(s, d = Date.today)
    active_now(for_user(s), d)
  end

  def self.for_user(s)
    ActivityPayments.matches_by_person_paid(s)
  end
end

class ActivityPayment < Entity
  def date_start
    Date.from_db(self._date_start)
  end

  def date_end
    Date.from_db(self._date_end)
  end

  def print
    st = person_paid
    date = System.run_str('LC_ALL=fr_FR.UTF-8 date +"%d %B %Y"')
    replace = {NAME1: st.first_name, NAME2: st.family_name,
               BDAY: st.birthday, ADDRESS: st.address, TOWN: st.town,
               TEL: st.phone, UNAME: st.login_name, PASS: st.password_plain,
               EMAIL: st.email, PROFESSION: st.profession, STUDY_LEVEL: st.school_grade,
               DATE: date, PRICE: activity.cost,
               DATE_START: date_start, DATE_END: date_end, ID: activitypayment_id}

    fname = "#{st.person_id.to_s.rjust(6, '0')}-#{st.full_name.gsub(/ /, '_')}"
    dputs(3) { "Replace is #{replace.inspect} - fname is #{fname}" }

    activity.print_card.print_hash(replace, nil, fname)
  end
end
