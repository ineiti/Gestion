# Gives a simple way to handle the different links to the accounts
# for different modules and different accounting-setups

class AccountLinks < Entities
  def setup_data
    value_entity_account :account
    value_str :link
    value_str :description
  end
  
  def self.get_account( link, default, description )
    ret = search_by_link( link ) and return ret
    return create( :link => link,
      :description => description,
      :account => Accounts.search_or_create( default ) )
  end
end