class ReportAccounts < Entities
  def setup_data
    value_entity_account :root, :drop
    value_entity_account :account, :drop
    value_int :level
  end
end


class Reports < Entities
  def setup_data
    value_str :name
    value_list_entity_reportAccounts :accounts
  end
end

class Report < Entity
  
  def print_account_monthly( acc, start, months, level )
    stop = start >> ( months - 1 )

    line = []
    zeros = false
    acc.account.get_tree( acc.level.to_i ){|acc_sub, depth|
      dputs(2){"Doing #{acc_sub.path} - #{depth.inspect}"}
      sum = Array.new(months){0}
      acc_sub.get_tree( depth > 0 ? 0 : -1 ){|acc_sum|
        acc_sum.movements.each{|m|
          if (start..stop).include? m.date
            sum[ m.date.month - start.month ] += m.get_value( acc_sum )
          end
        }
      }
      if sum.inject(false){|m,o| m |= o != 0} or line.size == 0
        if line.size == 0
          zeros = true
        elsif zeros
          line = []
          zeros = false
        end
        line.push [acc_sub.path, sum]
      end
    }
    line    
  end
  
  def print_heading_monthly( start = Date.today, months = 12 )
    ["Period", (0...months).collect{|m|
        ( start >> m ).strftime( "%Y/%m" )
      }]
  end
  
  def print_list_monthly( start = Date.today, months = 12 )
    stop = start >> ( months - 1 )
    list = accounts.collect{|acc|
      line = print_account_monthly( acc, start, months, acc.level )
      if line.size > 1
        line.push ["Sum", line.reduce( Array.new(months, 0) ){|memo, obj|
            dputs(2){"#{memo}, #{obj.inspect}"}
            memo = memo.zip( obj[1] ).map{|a,b| a + b}
          }]
      end
      line
    }
    if list.size > 1
      list + [[[ "Total", list.reduce( Array.new(months, 0)){|memo, obj|
              dputs(2){"#{memo}, #{obj.inspect}"}
              memo = memo.zip( obj.last.last ).map{|a,b| a + b }
            } ]]]
    else
      list
    end
  end
  
  def print( start = Date.today, months = 12 )
    
  end
  
  def listp_accounts
    accounts.collect{|a|
      [ a.id, "#{a.level}: #{a.account.path}" ]
    }
  end
  
  def print_pdf_monthly( start = Date.today, months = 12 )
    stop = start >> ( months - 1 )
    file = "/tmp/report_#{name}.pdf"
    Prawn::Document.generate( file,
      :page_size   => "A4",
      :page_layout => :landscape,
      :bottom_margin => 2.cm ) do |pdf|

      pdf.text "Report for #{name}", 
        :align => :center, :size => 20
      pdf.font_size 8
      pdf.text "From #{start.strftime('%Y/%m')} to #{stop.strftime('%Y/%m')}"
      pdf.move_down 1.cm

      pdf.table( [ print_heading_monthly( start, months ).flatten.collect{|ch|
            {:content => ch, :align => :center}}] + 
          print_list_monthly( start, months ).collect{|acc|
          acc.collect{|a, values| 
            [a] + values.collect{|v| Account.total_form( v ) } 
          }
        }.flatten(1).collect{|line|
          a, s = ( line[0] =~ /::/ ? [:left, :normal] : [:right, :bold] )
          [{:content => line.shift, :align => a, :font_style => s }] +
            line.collect{|v|
            {:content => v, :align => :right, :font_style => s } }
        },
        :header => true )
      pdf.move_down( 2.cm )

      pdf.repeat(:all, :dynamic => true) do
        pdf.draw_text "#{Date.today} - #{name}",
          :at => [0, -20], :size => 10
        pdf.draw_text pdf.page_number, :at => [18.cm, -20]
      end
    end
    file
  end
end