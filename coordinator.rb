require 'securerandom'

class Coordinator

  class CommandRejected < StandardError; end

  def initialize(workers)
    @workers = workers
  end

  def tx(session_id = nil, &block)
    session_id ||= SecureRandom.uuid

    puts "--> starting tx: #{session_id}"

    executor = lambda do |instruction|
      vote = instruction.worker.prepare(instruction.command, session_id)

      raise CommandRejected unless vote
    end

    block.call(executor)

    @workers.each { |worker| worker.commit!(session_id) }
  rescue CommandRejected
    @workers.each { |worker| worker.rollback(session_id) }
  end

end
