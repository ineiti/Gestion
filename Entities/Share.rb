# Holds share for samba

class Shares < Entities
  def setup_data
    value_block :config
    value_str :name
    value_str :path
    value_str :comment
    value_text :args
    value_list_drop :public, "%w( Yes No )"
    
    value_block :acl
    value_str :acl
  end
end

class Share < Entity
  def setup_instance
    if not self.acl
      self.acl = {}
    end
  end
end