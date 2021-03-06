require 'mole/worker/error'
require 'mole/worker/tag'
require 'mole/worker/request/common_parser'
require 'mole/worker/request/abst_request'

module Mole
  module Worker
    module Request


      class Search
        extend Mole::Worker::Tag
        extend Mole::Worker::Error

        include AbstRequest

        def initialize(*args)
          @protocol = :SearchRequest
          super
        end

        attr_reader :base_object, :scope, :deref_aliases, :size_limit, :time_limit, :types_only, :filter, :attributes

        # Parse SearchRequest. See RFC4511 Section 4.5
        def parse_request
          CommonParser.sanitize_length(@operation, 8, 'SearchRequest')

          @base_object = CommonParser.parse_ldap_dn(@operation.value[0], 'baseObject of SearchRequest')

          begin
            @scope = Tag::Scope[CommonParser.parse_enumerated(@operation.value[1], 'scope of SearchRequest')]
          rescue Error::KeyError
            raise Error::ProtocolError, "Receive unknown SearchRequest scope."
          end

          begin
            @deref_aliases = Tag::DerefAliases[CommonParser.parse_enumerated(@operation.value[2], 'derefAliases of SearchRequest')]
          rescue Error::KeyError
            raise Error::ProtocolError, "Receive unknown SearchRequest derefAliases."
          end

          @size_limit = CommonParser.parse_integer(@operation.value[3], 'sizeLimit of SearchRequest')
          @time_limit = CommonParser.parse_integer(@operation.value[4], 'timeLimit of SearchRequest')
          @types_only = CommonParser.parse_boolean(@operation.value[5], 'typesOnly of SearchRequest')
          @filter = parse_filter(@operation.value[6])
          @attributes = CommonParser.parse_sequence(@operation.value[7], 'attributes of SearchRequest').map do |attribute|
            CommonParser.parse_octet_string(attribute, 'Each SearchRequest attributes')
          end
        end

        def parse_filter(pdu)
          unless pdu.tag_class == :CONTEXT_SPECIFIC
            raise Error::ProtocolError, "filter of SearchRequest is requested to be Context-specific class ber."
          end

          filter_type = Tag::FilterType[pdu.tag]
          case filter_type
          when :and, :or, :not
              filter = parse_sub_filter(pdu)
          when :equality_match, :greater_or_equal, :less_or_equal, :approx_match
            filter = parse_attribute_value_assertion(pdu)
          when :substrings
            filter = parse_substring_filter(pdu)
          when :present
            filter = parse_present_filter(pdu)
          when :extensible_match
            filter = parse_matching_rule_assertion(pdu)
          end

          [filter_type, filter]
        rescue Error::KeyError
          raise Error::ProtocolError, "Receive unknown filter type."
        end

        # Use to extract individial filter from and, or, not filter
        def parse_sub_filter(pdu)
          CommonParser.sanitize_constructed(pdu, "'and', 'or' and 'not' Filter")

          pdu.value.map do |f|
            parse_filter(f)
          end
        end

        def parse_present_filter(pdu)
          CommonParser.sanitize_primitive(pdu, 'present Filter')
          pdu.value
        end

        def parse_substring_filter(pdu)
          CommonParser.sanitize_constructed(pdu, 'SubstringFilter')

          type = CommonParser.sanitize_octet_string(pdu.value[0], 'type of SubstringFilter')

          _initial = false
          _final = false
          substrings = CommonParser.parse_sequence(pdu, 'Each SubstringFilter').map do |s|
            CommonParser.sanitize_class(s, :CONTEXT_SPECIFIC, 'Each SubstringFilter substrings')

            case position = Tag::SubstringType[s.tag]
            when :initial
              raise Error::ProtocolError, "Tow or more than two initial substrings are in one SubstringFilter." if _initial
              _initial = true
            when :any
              # Do nothing
            when :final
              raise Error::ProtocolError, "Tow or more than two final substrings are in one SubstringFilter." if _final
              _final = true
            end
            [position, s.value]
          end

          [type, substrings]
        rescue Error::KeyError
          raise Error::ProtocolError, "Receive unknown SubstringFilter whose tag is #{s.tag}."
        end

        def parse_matching_rule_assertion(pdu)
          # TODO Implement
          raise Error::ProtocolError, "MatchingRuleAssertion parse is not implemented yet."
        end

        def parse_attribute_value_assertion(pdu)
          CommonParser.sanitize_length(pdu, 2, 'AttributeValueAssertion type Filter')

          [
            CommonParser.parse_octet_string(pdu.value[0], 'type of Filter AttributeValueAssertion'),
            CommonParser.parse_octet_string(pdu.value[1], 'value of Filter AttributeValueAssertion')
          ]
        end

      end

      private_constant :Search


    end
  end
end
