# AfriCompta - handler of a simple accounting-system for "Gestion"
#
# What follows are some definitions used by other modules

class SQLiteAC < SQLite
	def configure( config )
		filename = get_config( "compta.db", :AfriCompta, :filename )
		super( config, "compta", filename )
	end
end