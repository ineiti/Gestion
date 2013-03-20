# Place for different Helpers that are used by Gestion

# To help testing of command-stuff
module Command
  def run( cmd )
    %x[ #{cmd} ]
  end
end