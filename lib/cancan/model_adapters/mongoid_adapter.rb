module CanCan
  module ModelAdapters
    class MongoidAdapter < AbstractAdapter
      def self.for_class?(model_class)
        model_class <= Mongoid::Document
      end

      def self.override_conditions_hash_matching?(subject, conditions)
        conditions.any? do |k,v|
          key_is_not_symbol = lambda { !k.kind_of?(Symbol) }
          subject_value_is_array = lambda do
            subject.respond_to?(k) && subject.send(k).is_a?(Array)
          end

          key_is_not_symbol.call || subject_value_is_array.call
        end
      end

      def self.matches_conditions_hash?(subject, conditions)
        # To avoid hitting the db, retrieve the raw Mongo selector from
        # the Mongoid Criteria and use Mongoid::Matchers#matches?
        subject.matches?( subject.class.where(conditions).selector )
      end

      def no_records
        @model_class.where(:_id => {'$exists' => false, '$type' => 7})
      end

      def all_records
        @model_class.all
      end
      
      def database_records
        if @rules.size == 0
          @model_class.where(:_id => {'$exists' => false, '$type' => 7}) # return no records in Mongoid
        elsif @rules.size == 1 && @rules[0].conditions.is_a?(Mongoid::Criteria)
          @rules[0].conditions
        else
          @rules.reverse.inject(no_records) do |records, rule|
            if rule.conditions.empty?
              rule.base_behavior ? all_records : no_records
            else
              case records
              when all_records
                rule.base_behavior ? all_records : all_records.excludes(rule.conditions)
              when no_records
                rule.base_behavior ? all_records.or(rule.conditions) : no_records
              else
                rule.base_behavior ? records.or(rule.conditions) : records.excludes(rule.conditions)
              end
            end
          end
        end
      end
    end
  end
end

# simplest way to add `accessible_by` to all Mongoid Documents
module Mongoid::Document::ClassMethods
  include CanCan::ModelAdditions::ClassMethods
end
