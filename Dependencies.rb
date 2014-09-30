module Dependencies
  extend self

  def load_path( here: '.')
    $LOAD_PATH.push '.'
    $LOAD_PATH.push "#{here}/."
    $LOAD_PATH.concat %w( QooxView AfriCompta LibNet ).map{|p|
      "#{here}/../#{p}"
    }
    $LOAD_PATH.concat %w( Network HilinkModem SerialModem HelperClasses ).map { |p|
      "#{here}/../#{p}/lib"
    }
  end

  def load_dirs( here: '.' )
    %w( Modules Paths ).each { |dir|
      Dir.glob("#{here}/#{dir}/*").each { |d| require d }
    }
  end
end
