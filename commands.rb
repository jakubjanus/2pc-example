class AddCommand

  def initialize(addition)
    @addition = addition
  end

  def execute(value)
    value + @addition
  end

  def to_s
    "ADD #{@addition}"
  end

end
