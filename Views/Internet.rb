class Internet < View
  def layout
    set_data_class :Persons

    show_int_ro :credit
    show_button :connect, :disconnect

    dputs 5, "#{@layout.inspect}"
    @order = 100
    @visible = false
  end

  def rpc_show( sid )
    super( sid ) + [{ :cmd => "update", :data => update( sid )}]
  end
end