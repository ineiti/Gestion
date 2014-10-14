class SelfResults < View
  def layout
    @order = 10
    @visible = true
    @functions_need = [:quiz]

    gui_vbox do
      show_list :results, 'Quizs.results', :flexheight => 1
      show_button :update
    end
  end

  def rpc_button_update( session, data )
    reply( :empty_fields, [ :results ] ) +
    reply( :update, :results => Quizs.results )
  end
end
