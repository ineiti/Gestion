class SelfConcours < View
  def layout
    @order = 10
    @visible = false

    gui_vbox do
      gui_vbox :nogroup do
        show_html :welcome
      end
      gui_vbox :nogroup do
        show_str :email, :width => 300
        show_str :full_name, :width => 300
      end
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_list_drop :q01_isoc_start, "%w( répondez 1980 1992 2000 )"
          show_list_drop :q02_isoc_chad_start, "%w( répondez 2000 2003 2007 )"
          show_list_drop :q03_internet_sat, "%w( répondez vrai faux )"
          show_list_drop :q04_internet_like, "%w( répondez route avion eau )"
          show_list_drop :q05_internet_needs, "%w( répondez portable fai disque_dur )"
          show_list_drop :q06_fai_only_one, "%w( répondez vrai faux )"
          show_list_drop :q07_price_free, "%w( répondez vrai faux )"
          show_list_drop :q08_email_generic, "%w( répondez courriel yahoo gmail )"
          show_list_drop :q09_service_surf, "%w( répondez ftp www e-mail )"
          show_list_drop :q10_is_central, "%w( répondez vrai faux )"
        end
        gui_vbox :nogroup do
          show_list_drop :q11_internet_start, "%w( répondez recherche commercial )"
          show_list_drop :q12_what_standards, "%w( répondez ouvert payants )"
          show_list_drop :q13_chapters_count, "%w( répondez 80 90 100 )"
          show_list_drop :q14_isoc_members, "%w( répondez 57000 60000 55000 )"
          show_list_drop :q15_domain_names, "%w( répondez IANA IAB ICANN )"
          show_list_drop :q16_gives_ips, "%w( répondez IANA IAB ICANN )"
          show_list_drop :q17_does_standards, "%w( répondez IANA IAB ICANN )"
          show_list_drop :q18_we_work_with, "%w( répondez NTIC NPIC IPNT )"
          show_list_drop :q19_website_chad, "%w( répondez isoc-tchad.org isoc-chad.org isoc.td )"
          show_list_drop :q20_best_fai, "%w( répondez tigo airtel sotel prestabist tawali vsat )"
        end
      end
      gui_vbox :nogroup do
        show_button :send_replies
      end
      gui_window :error do
        show_html :txt_error
        show_button :ok
      end
      gui_window :finish do
        show_html :txt_finish
        show_button :yes, :no
      end
      gui_window :result do
        show_html :txt
        show_button :close
      end
    end
  end

  def rpc_show( session )
    super( session ) +
      reply( :update, :welcome => "<h1>ISOC-concours</h1>" )
  end

  def rpc_button_send_replies( session, data )
    if not data['email'] or not data['full_name'] then
      return reply( :window_show, :error ) +
        reply( :update, :txt_error => "Vous n'avez pas entré un nom<br>ou un courriel" )
    end
    reply( :window_show, :finish ) +
      reply( :update, :txt_finish => "Voulez vous terminer votre essai?<br>Vous ne pourriez plus rien changer" )
  end

  def rpc_button_ok( session, data )
    reply( :window_hide )
  end

  def rpc_button_no( session, data )
    reply( :window_hide )
  end

  def rpc_button_yes( session, data )
    replies = []
    data.sort{|a,b| a[0] <=> b[0] }.each{|d|
      dputs 5, "Data is #{d.inspect}"
      d[0] =~ /^q.._/ and replies.push d[1][0]
    }
    dputs 2, "replies is #{replies}"
    quiz = Quizs.create( :email => data['email'], :full_name => data['full_name'],
      :reply => replies.join(",") )
    greeting = case quiz.score
    when 0..5 then "Oups"
    when 6..10 then "Ca va"
    when 11..15 then "Bien"
    when 16..18 then "Très bien"
    when 19 then "Excellent"
    end
    reply( :window_hide ) +
      reply( :window_show, :result ) +
      reply( :update, :txt => "<h2>#{greeting}, votre score est de</h2><br><div align='center'><h1>#{quiz.score}/19</h1>" )
  end

  def rpc_button_close( session, data )
    reply( :window_hide ) +
      rpc_show( session )
  end
end
