require 'securerandom'

class Coordinator

  def initialize(workers)
    @workers = workers
  end

  def tx(instructions, session_id = nil)
    session_id ||= SecureRandom.uuid
    instructions.each { |instruction| instruction.apply(session_id) }

    if @workers.all? { |worker| worker.can_commit?(session_id) }
      @workers.each { |worker| worker.commit!(session_id) }
    else
      @workers.each { |worker| worker.rollback(session_id) }
    end
  end

end
