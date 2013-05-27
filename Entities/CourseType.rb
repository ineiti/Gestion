# To change this template, choose Tools | Templates
# and open the template in the editor.

class CourseTypes < Entities
  def setup_data
    value_str :filename

    value_block :strings
    value_str :name
    value_str :duration
    value_int :tests
    
    value_block :long
    value_str :description
    value_text :contents
    
    value_block :central
    value_list_drop :diploma_type, "%w( simple files accredited )"
    value_str :central_host
    value_int :files_needed
    value_list_drop :output, "%w( certificate label )"
  end
  
  def self.files
    begin
      ddir = get_config( "Diplomas", :Courses, :DiplomaDir )
      ( Dir.glob( ddir + "/*odt" ) +
        Dir.glob( ddir + "/*odg" ) ).
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
  
  def listp_profeda_code
    self.search_by_profeda_code( "^.+$" ).collect{|ct|
      [ ct.coursetype_id, ct.profeda_code ]
    }
  end
  
  def listp_name
    self.search_by_profeda_code( "^$" ).collect{|ct|
      [ ct.coursetype_id, ct.name ]
    }
  end
  
  def migration_1(ct)
    ct.tests = 1
    ct.output = ["certificate"]
  end

  def migration_2(ct)
    ct.diploma_type = ["simple"]
  end
end


class CourseType < Entity
  def get_unique
    name
  end
end
