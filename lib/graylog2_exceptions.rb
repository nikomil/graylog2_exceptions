require 'rubygems'
require 'gelf'
require 'socket'

class Graylog2Exceptions
  attr_reader :args
  attr_reader :custom_attributes

  def initialize(app, args = {})
    standard_args = {
      :hostname => "localhost",
      :port => 12201,
      :local_app_name => Socket::gethostname,
      :facility => 'graylog2_exceptions',
      :max_chunk_size => 'LAN',
      :level => 3
    }

    # Move extra arguments to separate hash
    @custom_attributes = {}
    args.each_key do |key|
        if not standard_args.has_key?(key) then
            @custom_attributes[key] = args.delete(key)
        end
    end

    @args = standard_args.merge(args)
    @app = app
  end

  def call(env)
    # Make thread safe
    dup._call(env)
  end

  def _call(env)
    begin
      # Call the app we are monitoring
      @app.call(env)
    rescue Exception => err
      # An exception has been raised. Send to Graylog2!
      send_to_graylog2(err)

      # Raise the exception again to pass back to app.
      raise
    end
  end

  def send_to_graylog2 err
    begin
      notifier = GELF::Notifier.new(@args[:hostname], @args[:port], @args[:max_chunk_size])
      notifier.notify!({
				:short_message => err.message,
        :full_message => err.backtrace.join("\n"),
        :facility => @args[:facility],
        :level => @args[:level],
        :host => @args[:local_app_name],
        :file => err.backtrace[0].split(":")[0],
        :line => err.backtrace[0].split(":")[1],
			}.merge(@custom_attributes))
    rescue => i_err
      puts "Graylog2 Exception logger. Could not send message: " + i_err.message
    end
  end
end
