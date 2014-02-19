require 'openssl'

require 'mole/worker/error'

module Mole
  module Worker
    module Request
      extend Mole::Worker::Error

      class AbstRequest
        def initialize(message_id, operation)
          @message_id = message_id
          @operation = operation
          parse_request
        rescue Error::LdapError
          @error = $!
        end

        attr_reader :message_id, :protocol, :error

        private

        def parse_request
          # Implement in each child class
        end
      end


    end
  end
end
