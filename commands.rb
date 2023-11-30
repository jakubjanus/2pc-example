class AddCommand

  def initialize(addition)
    @addition = addition
  end


  def execute(value)
    value + @addition
  end

end
