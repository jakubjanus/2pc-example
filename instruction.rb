class Instruction

  def initialize(worker, command)
    @worker = worker
    @command = command
  end

  attr_reader :worker, :command

end
