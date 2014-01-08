# Allow for courses to be paid
# Can search by courses or by students

class ComptaCourse < View
  def layout
    @order = 0
    @visible = false
  end
end
