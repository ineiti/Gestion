=begin
 Offers simple OpenOffice-find/replace stuff and printing 
=end

require 'rubygems'
require 'docsplit'

class OpenPrint
  def initialize( file )
    @file = file
    @base = `basename #{file}`
    @default_printer = "-P #{$config[:default_printer]}"
    @counter = 0
  end

  def print( fields )
    dputs 3, "New print for #{@file}"
    tmp_file = "/tmp/#{@counter}-#{@base}"
    pdf_file = tmp_file.sub(/[^\.]*$/, 'pdf')
    cmd = "lpr #{@default_printer} #{pdf_file}"

    FileUtils::cp( @file, tmp_file )
    ZipFile.open( tmp_file ){ |z|
      doc = z.read("content.xml")
      fields.each{|f|
        doc.gsub!( f[0], f[1].to_s )
      }
      z.file.open("content.xml", "w"){ |f|
        f.write( doc )       
      }
      z.commit
    }

    Docsplit.extract_pdf tmp_file, :output => "/tmp"
    dputs 5, "Finished docsplit"
    FileUtils::rm( tmp_file )
    dputs 0, cmd
    `#{cmd}`
  end
end