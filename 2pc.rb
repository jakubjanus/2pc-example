require 'securerandom'

class Coordinator

  def initialize(workers)
    @workers = workers
  end

  def tx(instructions)
    session_id = SecureRandom.uuid
    instructions.each { |instruction| instruction.apply(session_id) }

    if @workers.all? { |worker| worker.can_commit?(session_id) }
      @workers.each { |worker| worker.commit!(session_id) }
    else
      @workers.each { |worker| worker.rollback(session_id) }
    end
  end

end

class Worker

  class LockNotObtained < StandardError; end

  def initialize(value = 0)
    @value = value
    @rules = []
    @semaphore = Mutex.new
    @sessions = {}
    @current_session = nil
  end

  def add_rule(rule)
    @rules.push(rule)
  end

  def apply(command, session)
    @semaphore.synchronize do
      (@sessions[session] ||= []).push(command)
    end
  end

  def can_commit?(session)
    @semaphore.synchronize do
      return false unless @current_session.nil?

      @current_session = session
    end

    commands = @sessions[@current_session]
    @rules.all? do |rule|
      new_value = @value
      commands.all? do |command|
        new_value = command.execute(new_value)
        rule.call(new_value)
      end
    end
  end

  def commit!(session)
    raise 'Cannot commit this command' unless session == @current_session

    commands = @sessions[@current_session]
    @semaphore.synchronize do
      commands.each do |command|
        @value = command.execute(@value)
      end
    end

    release(session)
  end

  def rollback(session)
    release(session)
  end

  attr_reader :value

  private

  def release(session)
    @semaphore.synchronize do
      @sessions.delete(session)
      @current_session = nil if session == @current_session
    end
  end

end

class Instruction

  def initialize(worker, command)
    @worker = worker
    @command = command
  end

  def apply(session_id)
    @worker.apply(@command, session_id)
  end

end

class AddCommand

  def initialize(addition)
    @addition = addition
  end


  def execute(value)
    value + @addition
  end

end

worker_1 = Worker.new(10)
worker_1.add_rule ->(value) { value >= 0 }
worker_2 = Worker.new(30)
worker_2.add_rule ->(value) { value < 100 }

coordinator = Coordinator.new([worker_1, worker_2])

# instructions = [
#   Instruction.new(worker_1, AddCommand.new(-1)),
#   Instruction.new(worker_2, AddCommand.new(44))
# ]

t1 = Thread.new do
  wait = rand(1000)
  sleep(wait / 1000.0)

  instructions = [
    Instruction.new(worker_1, AddCommand.new(5)),
    Instruction.new(worker_2, AddCommand.new(44))
  ]
  coordinator.tx(instructions)
end

t2 = Thread.new do
  wait = rand(1000)
  sleep(wait / 1000.0)

  instructions = [
    Instruction.new(worker_1, AddCommand.new(-11)),
    Instruction.new(worker_2, AddCommand.new(20)),
    Instruction.new(worker_1, AddCommand.new(1))
  ]
  coordinator.tx(instructions)
end

t1.join
t2.join


puts 'End values:'
puts "worker_1: #{worker_1.value}"
puts "worker_2: #{worker_2.value}"

