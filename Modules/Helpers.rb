# Place for different Helpers that are used by Gestion

# To help testing of command-stuff
module Command
  def self.run( cmd )
    %x[ #{cmd} ]
  end
end