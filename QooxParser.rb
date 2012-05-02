require 'rubygems'
require 'gettext'

include GetText

module QooxParser
  module_function
  # If the file is the target of your parser, then return true, otherwise false.
  def target?(file)
    File.extname(file) == ".rb"
  end

  def parse(file)
    ary = []
    File.open( file ){|f|
      line = 0
      f.readlines.each{|l|
        line += 1
        if l =~ /^\s*value_.*/ or l =~ /^\s*show_.*/
          case l
          when /(value_block|show_block)/
          when /show_button/
            buttons = l.sub( /^[^:]*:/, '' ).gsub( /:/, '' ).chop.split( /,\s*/ )
            buttons.each{|b|
              po = PoMessage.new(:normal)
              po.msgid = b
              po.sources = "#{file}:#{line}"
              po.add_comment( "Comes from file #{file} and line is #{l}" )
              ary << po
            }
          else
          po = PoMessage.new(:normal)
          po.msgid = l.sub( /^[^:]*:/, '' ).sub( /,.*/, '' ).chop
          po.sources = "#{file}:#{line}"
          po.add_comment( "Comes from file #{file} and line is #{l}" )
          ary << po
          end
        end
      }
    }
    return ary
  end

end

# Add this parser to GetText::RGetText
RGetText.add_parser(QooxParser)
