require_relative 'worker'
require_relative 'coordinator'
require_relative 'commands'
require_relative 'instruction'

worker_a = Worker.new('A', 10)
worker_a.add_rule ->(value) { value >= 0 }
worker_b = Worker.new('B', 30)
worker_b.add_rule ->(value) { value < 100 }

coordinator = Coordinator.new([worker_a, worker_b])

def sleep_random
  wait_in_ms = rand(1000)
  sleep(wait_in_ms / 1000.0)
end

t1 = Thread.new do
  sleep_random

  coordinator.tx('t1') do |executor|
    executor.call Instruction.new(worker_a, AddCommand.new(5))
    sleep_random
    executor.call Instruction.new(worker_b, AddCommand.new(44))
  end
end

t2 = Thread.new do
  sleep_random

  coordinator.tx('t2') do |executor|
    executor.call Instruction.new(worker_a, AddCommand.new(-11))
    executor.call Instruction.new(worker_b, AddCommand.new(20))
    sleep_random
    executor.call Instruction.new(worker_a, AddCommand.new(1))
  end
end

t1.join
t2.join

puts "\n\n"
puts 'End values:'
puts "worker_1: #{worker_a.value}"
puts "worker_2: #{worker_b.value}"

