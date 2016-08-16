# Find destructive SQL queries to utilize replica DB on GET HTTP requests
module SqlLogSubscriber
  class Railtie < ::Rails::Railtie # :nodoc:
    config.sql_log_subscriber = ActiveSupport::OrderedOptions.new

    config.after_initialize do |app|
      if active?(app)
        Core.request_context = RequestStore
        Core.logger          = SqlLogSubscriber::Logger.new(logger: sql_active_logger)
      end
    end

    initializer 'sql_log_subscriber.configure' do |app|
      if active?(app)
        load
        ::Rails.logger.info '[SqlLogSubscriber] enabled'
      end
    end

    private

    def active?(app)
      app.config.sql_log_subscriber.enabled
    end

    def sql_active_logger
      ::Rails.env.production? ? LOG_STASH_LOGGER : ::Rails.logger
    end

    def load
      require_relative 'core'
      require_relative 'logger'
    end
  end
end
