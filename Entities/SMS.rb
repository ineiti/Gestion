# Holds SMS from Modem

class SMSs < Entities
  def setup_data
    value_date :date
    value_phone :phone
    value_txt :text
    value_int :index
  end

  def last(count)
    return [] if @data.length == 0 || count <= 0

    msgs = [count, @data.length].min
    dputs(3) { "Getting #{msgs} SMS for #{@data.inspect}" }
    @data.keys.sort[-msgs..-1].collect { |d|
      get_data_instance(d)
    }
  end

  def create(sms)
    if !match_by_date(sms._date)
      super({date: sms._date, phone: sms._number, text: sms._msg,
             index: sms._id})
    end
    while @data.length > 50
      get_data_instance(@data.first.first).delete
    end
  end
end
