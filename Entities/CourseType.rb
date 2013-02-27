# To change this template, choose Tools | Templates
# and open the template in the editor.

class CourseTypes < Entities
  def setup_data
    value_str :filename

    value_block :strings
    
    value_str :name
    value_str :duration
    value_str :description
    value_text :contents
  end
  
  def self.files
    begin
      Dir.glob( $config[:DiplomaDir] + "/*odt" ).
        collect{|f| f.sub( /^.*\//, '' ) }
    end
  end

  def set_entry( id, field, value )
    case field.to_s
    when "name"
      value.gsub!(/[^a-zA-Z0-9_-]/, '_' )
    end
    super( id, field, value )
  end
end
