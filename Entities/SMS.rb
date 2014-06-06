# Holds SMS from Modem

class SMSs < Entities
  def setup_data
    value_date :date
    value_phone :phone
    value_txt :text
    value_int :index
  end

  def last( count )
    return [] if @data.length == 0 || count <= 0

    msgs = [ count, @data.length ].min
    dputs(3){"Getting #{msgs} SMS for #{@data.inspect}"}
    @data.keys.sort[-msgs..-1].collect{|d|
      get_data_instance( d )
    }
  end

  def create( msg )
    super( {date: msg._Date, phone: msg._Phone, text: msg._Content,
           index: msg._Index})
  end
end
