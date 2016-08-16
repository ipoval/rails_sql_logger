# Find destructive SQL queries to utilize replica DB on GET HTTP requests
module SqlLogSubscriber
  class Logger
    SQL_COMMENTS_REGEXP = %r{/\*(\*(?!/)|[^*])*\*/}
    BACKTRACE_LINES_INCLUDED = 10
    BACKTRACE_EXCLUSIONS = %r{sql_log_subscriber|gems}
    OBFUSCATION_ERROR_MESSAGE = 'Failed to obfuscate query'.freeze

    def initialize(opts = {})
      @logger         = opts.fetch(:logger) { LOG_STASH_LOGGER }
      @cleaner        = opts.fetch(:backtrace_cleaner) { default_backtrace_cleaner }
      @obfuscator     = opts.fetch(:obfuscator) { NewRelic::Agent::Database }
      @skip_backtrace = opts.fetch(:skip_backtrace, false)
    end

    def info(opts = {})
      logger.info generate_event(opts)
    end

    private

    attr_reader :cleaner, :logger, :obfuscator, :skip_backtrace

    def generate_event(opts)
      event = {
        project:         'replica_db_on_http_get',
        event:           'sql.active_record',
        query:           obfuscate(opts[:sql].to_s),
        controller_name: opts[:controller_name].to_s,
        action_name:     opts[:action_name].to_s,
        request_method:  opts[:request_method].to_s,
        request_path:    opts[:request_path].to_s,
        request_id:      opts[:request_id].to_s
      }
      event[:backtrace] = backtrace unless skip_backtrace
      event
    end

    def obfuscate(sql)
      obfuscator.obfuscate_sql(sql.gsub(SQL_COMMENTS_REGEXP, '')).chomp
    rescue StandardError
      OBFUSCATION_ERROR_MESSAGE
    end

    def backtrace
      cleaner.clean(caller)[0...BACKTRACE_LINES_INCLUDED].join("\n")
    end

    def default_backtrace_cleaner
      ActiveSupport::BacktraceCleaner.new.tap do |cleaner|
        cleaner.add_silencer { |line| line =~ BACKTRACE_EXCLUSIONS }
      end
    end
  end
end
