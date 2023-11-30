class Instruction

  def initialize(worker, command)
    @worker = worker
    @command = command
  end

  def apply(session_id)
    @worker.apply(@command, session_id)
  end

end
