class Worker

  class LockNotObtained < StandardError; end

  def initialize(name, value = 0)
    @name = name
    @value = value
    @rules = []
    @semaphore = Mutex.new
    @sessions_values = {}
    @current_session = nil
  end

  def add_rule(rule)
    @rules.push(rule)
  end

  def prepare(command, session)
    @semaphore.synchronize do
      return false unless @current_session.nil? || @current_session == session

      @current_session = session
      new_value_candidate = command.execute(@sessions_values[session] || @value)
      @sessions_values[session] = new_value_candidate

      @rules.all? { |rule| rule.call(new_value_candidate) }
    end
  end

  def commit!(session)
    raise 'Cannot commit this command' unless session == @current_session

    puts "--> [Worker #{@name}] committing #{session}"

    @semaphore.synchronize do
      @value = @sessions_values[session]
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
      @sessions_values.delete(session)
      @current_session = nil if session == @current_session
    end
  end

end
