require 'mole/worker/error'

module Mole
  module Worker
    module Response
      extend Mole::Worker::Error


      class Entry

        class IgnoreCaseHash < Hash

          def has_key?(key)
            keys.any? do |k|
              k =~ /^#{key}$/i
            end
          end

          def [](key)
            each_pair do |k, v|
              return v if k =~ /^#{key}$/i
            end

            nil
          end

          def []=(key, value)
            delete(key)
            super
          end

          def delete(key)
            keys.each do |k|
              return super(k) if k =~ /^#{key}$/i
            end
            nil
          end
        end

        class Attributes < IgnoreCaseHash

          def self.[](attributes)
            ret = new

            attributes.each do |attr|
              unless attr.length == 2
                raise ArgumentError, "invalid number of elements. (#{attr.length} for 2)"
              end

              type = attr[0]
              vals = attr[1]

              unless vals..is_a?(Array)
                raise TypeError, "Each attribute vallues must be Array"
              end

              ret[type] = vals
            end

            ret
          end

          private :initialize

          def select(filter)
            send(*filter)
          end

          private

          def and(filters)
            filters.map { |filter|
              select(filter)
            }.all?
          end

          def or(filters)
            filters.map { |filter|
              select(filter)
            }.any?
          end

          def not(filter)
            not select(filter)
          end

          def equality_match(attribute)
            type = attribute[0]
            value = attribute[1]

            return false unless has_key?(type)

            self[type].any? do |v|
              v =~ /^#{value}$/i
            end
          end

          def substrings(substring)
            type = substring[0]

            substring[1].map { |sub|
              position = sub[0]
              value = sub[1]

              return false unless has_key?(type)
              case position
              when :initial
                self[type].any? do |v| v =~ /^#{value}/i end
              when :any
                self[type].any? do |v| v =~ /#{value}/i end
              when :final
                self[type].any? do |v| v =~ /#{value}$/i end
              end
            }.all?
          end

          def greater_or_equal(attribute)
            type = attribute[0]
            value = attribute[1]

            return false unless has_key?(type)

            self[type].any? do |v|
              v.downcase >= value.downcase
            end
          end

          def less_or_equal(attribute)
            type = attribute[0]
            value = attribute[1]

            return false unless has_key?(type)

            self[type].any? do |v|
              v.downcase <= value.downcase
            end
          end

          def present(type)
            has_key?(type)
          end

          def approx_match(attribute)
            # There is no self approximate matching rule,
            # so behave as equality mathcing according to RFC4511 Section 4.5.1.7.6
            equality_match(attribute)
          end

          def extensible_match(attribute)
            matching_rule = attribute[0]
            type = attribute[1]
            match_value = attribute[2]
            dn_attributes = attribute[3] || false

            if dn_attributes
              # TODO Implement extensible_match when dn_attribute is True
              raise Error::ProtocolError, "extensibleMatch filter rule with dn attributes is not implemented yet."
            end

            if matching_rule and type
              select([matching_rule, [type, match_value]])
            elsif (not matching_rule) and type
              equality_match([type, match_value])
            elsif matching_rule and (not type)
              keys.map { |t|
                select([matching_rule, [t, match_value]])
              }.any?
            else
              raise Error::ProtocolError, "Neither mathingRule nor type is not specified in extensibleMatch filter."
            end
          end
        end

        @@base = nil
        @@mutex = Mutex.new

        def initialize(dn, attributes)
          @dn = dn.freeze
          @attributes = Attributes[attributes]
          @children = IgnoreCaseHash.new
        end

        attr_reader :dn, :attributes, :children

        # Deep copy, but not join itself to DN tree
        def initialize_copy(original)
          @attributes = @attributes.clone
          @children = @children.reduce(IgnoreCaseHash.new) do |acc, val|
            acc[val[0]] = val[1]
            acc
          end
        end

        def base?
          equal?(@@base)
        end

        def self.clear
          @@mutex.synchronize {
            @@base = nil
          }
        end

        def self.add(dn, attributes)
          @@mutex.synchronize {
            if @@base
              raise Error::EntryAlreadyExistsError, "#{dn} is already exists." if @@base.dn == dn
              Entry.new(dn, attributes).join
            else
              @@base = new(dn, attributes)
            end
          }
        end

        def join
          raise Error::EntryAlreadyExistsError, "#{@dn} is already exists." if parent.children.has_key?(rdn)
          parent.children[rdn] = self
        rescue Error::NoSuchObjectError
          raise Error::UnwillingToPerformError, "Parent entry is not found."
        end

        def self.modify(dn, operations)
          @@mutex.synchronize {
            raise Error::NoSuchObjectError, "Basedn doesn't exist." unless @@base
            target = @@base.search(dn, :base_object)[0]
            replace = target.clone

            operations.each do |operation|
              replace.modify(operation)
            end

            if target.base?
              @@base = replace
            else
              target.delete
              replace.join
            end
          }
        end

        def delete
          if base?
            @@base = nil
          else
            parent.children.delete(rdn) ||
              (raise RuntimeError, "Assertion. This instance is neither base dn nor child of another.")
          end
        rescue Error::NoSuchObjectError
          raise RuntimeError, "Assertion. Parent entry is not found."
        end

        # modify its attribute.
        def modify(operation)
          command = operation[0]
          type, values = operation[1]

          case command
          when :add
            if @attributes.has_key?(type)
              @attributes[type] = @attributes[type] + values
            else
              @attributes[type] = values
            end
          when :delete
            raise Error::NoSuchAttributeError, 'No such attribute is.' unless @attributes.has_key?(type)
            if values.empty?
              @attributes.delete(type)
            else
              values.each do |v|
                @attributes[type].delete(v) ||
                (raise Error::NoSuchAttributeError, "Attribute #{type} doesn't have value #{v}.")
              end
              @attributes.delete(type) if @attributes[type].empty?
            end

          when :replace
            if values.empty?
              @attributes.delete(type)
            else
              @attributes[type] = values
            end
          end
        end

        def self.search(dn, scope, attributes, filter)
          @@mutex.synchronize {
            raise Error::NoSuchObjectError, "Basedn doesn't exist." unless @@base
            ret = @@base.search(dn, scope).select { |entry|
              entry.attributes.select(filter)
            }.map { |entry|
              Entry.new(entry.dn, entry.select_attributes(attributes))
            }
            raise Error::NoSuchObjectError, 'No entry is hit.' if ret.empty?
            ret
          }
        end

        def search(dn, scope)
          raise RuntimeError, 'Assertion. search method is called from not base dn.' unless base?

          if dn =~ /^#{@dn}$/i or dn =~ /,#{@dn}$/i
            # Search dn is equals or longer than base dn.
            relative_dns = dn.sub(/,?#{@dn}$/i, '').split(',')
            ret = iter_search(relative_dns, scope)

          elsif @dn =~ /,#{dn}$/i
            # Search dn is shorter than base dn.
            case scope
            when :base_object
              raise Error::NoSuchObjectError, "#{dn} doesn't match to base dn."
            when :single_level
              if "#{rdn},#{dn}" =~ /^#{@dn}$/i
                # Search dn is parent of Base DN.
                ret = [self]
              else
                raise Error::NoSuchObjectError, "#{dn} doesn't match to base dn."
              end
            when :whole_subtree
              ret = iter_search([], scope)
            end

          else
            # Search dn doesn't match to base dn.
            raise Error::NoSuchObjectError, "#{dn} doesn't match to base dn."
          end

          raise Error::NoSuchObjectError, "No entry is hit." if ret.empty?
          ret
        end

        def select_attributes(attributes)
          if attributes.empty?
            @attributes.clone

          elsif attributes.include?('*')
            @attributes.clone

          elsif attributes == ['1.1']
            []

          else
            attributes.reduce([]) do |acc, type|
              acc << [type, @attributes[type]] if @attributes.has_key?(type)
              acc
            end
          end
        end

        def self.del(dn)
          @@mutex.synchronize {
            raise Error::NoSuchObjectError, "Basedn doesn't exist." unless @@base
            entry = @@base.search(dn, :base_object)[0]
            raise Error::NotAllowedOnNonLeafError, "#{dn} is not a leaf entry." unless entry.leaf?
            entry.delete
          }
        end

        def self.modify_dn(old_dn, new_rdn, delete_old, new_parent_dn)
          @@mutex.synchronize {
            old_entry = @@base.search(old_dn, :base_object)[0]

            # Make it a rule not to move Base DN following OpenLDAP.
            raise Error::UnwillingToPerformError, "#{old_dn} is Base DN." if old_entry.base?

            new_parent_dn = old_entry.dn unless new_parent_dn

            old_entry.iter_copy("#{new_rdn},#{new_parent_dn}")
            old_entry.delete if delete_old
          }
        end

        # Copy and join itself to new dn including its children recursively.
        def iter_copy(dn)
          new_entry = Entry.new(dn, @attributes.clone).join
          @children.values.each do |child|
            child.iter_copy("#{child.rdn},#{dn}")
          end
          new_entry
        end

        def leaf?
          @children.empty?
        end

        def rdn
          @dn.split(',', 2)[0]
        end

        def parent
          parent_dn = @dn.split(',', 2)[1]
          raise Error::NoSuchObjectError, "Parent entry of #{@dn} is not found." unless parent_dn
          @@base.search(parent_dn, :base_object)[0] ||
            (raise Error::NoSuchObjectError, "Parent entry of #{@dn} is not found.")
        end

        def iter_search(relative_dns, scope)
          if relative_dns.empty?
            case scope
            when :base_object
              [self]
            when :single_level
              @children.values << self
            when :whole_subtree
              @children.values.reduce([self]) do |acc, child|
                acc + child.iter_search(relative_dns, scope)
              end
            end
          else
            next_dn = relative_dns.pop
            if @children.has_key?(next_dn)
              @children[next_dn].iter_search(relative_dns, scope)
            else
              raise Error::NoSuchObjectError, "No entry is found."
            end
          end
        end

        protected :iter_search, :children

      end


    end
  end
end
