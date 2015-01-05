class Netdevs < Entities
  def setup_data
    value_str :name
    value_str :ip
    value_int :netlength
    value_str :gateway
    value_list_drop :type, '%w( net host router modem )'
    value_list :action, '%w( ping traffic )'
  end
end