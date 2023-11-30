class Coordinator

  def initialize(workers)
    @workers = workers
  end

  def tx(instructions)
    if instructions.all?(&:can_commit?)
      instructions.each(&:commit!)
    else
      instructions.each(&:rollback)
    end
  end

end

class Worker

  class LockNotObtained < StandardError; end

  def initialize(value = 0)
    @value = value
    @rules = []
    @semaphore = Mutex.new
    @current_command = nil
  end

  def add_rule(rule)
    @rules.push(rule)
  end

  def apply(command)
    @semaphore.synchronize do
      raise LockNotObtained unless @current_command.nil?

      @current_command = command
    end
  end

  def can_commit?(command)
    return false unless command == @current_command

    @new_value = @current_command.execute(@value)

    @rules.all? { |rule| rule.call(@new_value) }
  end

  def commit!(command)
    raise 'Cannot commit this command' unless command == @current_command

    @value = @new_value
    release
    true
  end

  def rollback(command)
    return unless command == @current_command

    release
    true
  end

  attr_reader :value

  private

  def release
    @semaphore.synchronize do
      @new_value = nil
      @current_command = nil
    end
  end

end

class Instruction
  def initialize(worker, command)
    @worker = worker
    @command = command
  end

  def can_commit?
    @worker.apply(@command)
    @worker.can_commit?(@command)
  end

  def commit!
    @worker.commit!(@command)
  end

  def rollback
    @worker.rollback(@command)
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
    Instruction.new(worker_2, AddCommand.new(20))
  ]
  coordinator.tx(instructions)
end

t1.join
t2.join


puts 'End values:'
puts "worker_1: #{worker_1.value}"
puts "worker_2: #{worker_2.value}"

# BEGIN
# ADD x, 1
# SUB y, 2
# COMMIT
