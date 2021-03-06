module Mole
  module Worker
    module Error


      class LdapError < StandardError
      end

      class UnwillingToPerformError < LdapError
        @@code = :unwillingToPerform
        def code
          @@code
        end
      end

      class EntryAlreadyExistsError < LdapError
        @@code = :entryAlreadyExists
        def code
          @@code
        end
      end

      class InvalidDNSyntaxError < LdapError
        @@code = :invalidDNSyntax
        def code
          @@code
        end
      end

      class NoSuchObjectError < LdapError
        @@code = :noSuchObject
        def code
          @@code
        end
      end

      class ProtocolError < LdapError
        @@code = :protocolError
        def code
          @@code
        end
      end

      class AuthMethodNotSupported < LdapError
        @@code = :authMethodNotSupported
        def code
          @@code
        end
      end

      class NoSuchAttributeError < LdapError
        @@code = :noSuchAttribute
        def code
          @@code
        end
      end

      class NotAllowedOnNonLeafError < LdapError
        @@code = :notAllowedOnNonLeaf
        def code
          @@code
        end
      end


    end
  end
end
