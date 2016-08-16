require 'active_support/notifications'

# Find destructive SQL queries to utilize replica DB on GET HTTP requests
module SqlLogSubscriber
  class Core # :nodoc:
    class_attribute :request_context
    class_attribute :logger

    def call(*args)
      return if request_context.blank?
      return if ignore_payload?(payload = args.last)

      logger.info(
        request_context.store.slice(:request_method, :request_path, :controller_name, :action_name, :request_id)
        .merge!(sql: payload[:sql])
      )
    end

    private

    def request_context
      self.class.request_context
    end

    def logger
      self.class.logger
    end

    def ignore_payload?(payload)
      payload[:exception] || IGNORED_PAYLOADS.include?(payload[:name]) || payload[:sql].to_s !~ TRACKED_SQLS
    end

    # ignore SCHEMA, EXPLAIN and queries to query cache.
    IGNORED_PAYLOADS = %w(SCHEMA EXPLAIN CACHE).freeze
    TRACKED_SQLS = /\A\s*(update|delete|insert)\b/i

    ActiveSupport::Notifications.subscribe('sql.active_record', new)
  end
end
