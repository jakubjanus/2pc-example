class Worker

  class LockNotObtained < StandardError; end

  def initialize(name, value = 0)
    @name = name
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

    puts "--> [Worker #{@name}] committing #{session}"

    commands = @sessions[@current_session]
    @semaphore.synchronize do
      commands.each do |command|
        @value = command.execute(@value)
      end
    end

    release(session)
  end

  def rollback(session)
    puts "--> [Worker #{@name}] rollbacking #{session}"

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
