require 'feature_flags/flag_rule'

module FeatureFlagsGeneral
  class FlagStorage
    STATE = 'state'.freeze
    LIST = 'list'.freeze

    def initialize(redis, options = {})
      @redis = redis

      @namespace = options.fetch(:namespace) { nil }
      @rule = options.fetch(:flag_rule) { default_rule(FlagRule.new) }

      yield(@rule) if block_given?
    end

    # e.g. set_global_feature(:city, city_id, :feature, :live)
    # => 'OK'
    def set_global_feature(key, value, feature, to_state)
      @rule.states.each do |state|
        namespaced_key = namespaced_key(STATE, feature, state, key, value)
        if state == to_state
          @redis.sadd(namespaced_key, value)
        else
          @redis.srem(namespaced_key, value)
        end
      end
    end

    # e.g. global_feature(:city, city_id, :feature)
    # => :live
    def global_feature(key, value, feature)
      @rule.states.each do |state|
        namespaced_key = namespaced_key(STATE, feature, state, key, value)
        return state if @redis.sismember(namespaced_key, value)
      end

      nil
    end

    # e.g. global_features(:city, city_id, [:feature, :feature_B])
    # => { feature: :live, feature_B: nil }
    def global_features(key, value, features)
      features.each_with_object({}) do |feature, hash|
        hash[feature] = global_feature(key, value, feature)
      end
    end

    # e.g. set_local_feature(:user, user_id, :feature, :whitelist)
    # => 'OK'
    def set_local_feature(key, value, feature, to_list)
      @rule.lists.each do |list|
        namespaced_key = namespaced_key(LIST, feature, list, key, value)
        if list == to_list
          @redis.sadd(namespaced_key, value)
        else
          @redis.srem(namespaced_key, value)
        end
      end
    end

    # e.g. local_feature(:user, user_id, :feature)
    # => :whitelist
    def local_feature(key, value, feature)
      @rule.lists.each do |list|
        namespaced_key = namespaced_key(LIST, feature, list, key, value)
        return list if @redis.sismember(namespaced_key, value)
      end

      nil
    end

    # e.g. local_features(:user, user_id, [:feature, :feature_B])
    # => { feature: :whitelist, feature_B: nil }
    def local_features(key, value, features)
      features.each_with_object({}) do |feature, hash|
        hash[feature] = local_feature(key, value, feature)
      end
    end

    # e.g. feature?(:city, city_id, :user, user_id, :feature)
    # => true
    def feature?(global_key, global_val, local_key, local_val, feature)
      return false if global_val.nil?

      state = global_feature(global_key, global_val, feature)
      list = local_feature(local_key, local_val, feature)

      @rule.feature_checker.call(state, list)
    end

    # e.g. features(:city, city_id, :user, user_id, [:feature, :feature_B])
    # => { feature: true, feature_B: false }
    def features?(global_key, global_val, local_key, local_val, features)
      features.each_with_object({}) do |feature, hash|
        hash[feature] = feature?(global_key, global_val, local_key, local_val, features)
      end
    end

    private

    def namespaced_key(*parts)
      key = @rule.key_generator ? @rule.key_generator.call(*parts) : parts[0..-2].join('_'.freeze)
      @namespace ? "#{@namespace}_#{key}" : key
    end

    def default_rule(rule)
      rule.states = %i(live beta)
      rule.lists = %i(whitelist blacklist)

      rule.feature_checker = ->(state, list) do
        return true if :live == state && :blacklist != list
        return true if :beta == state && :whitelist == list

        false
      end

      rule
    end
  end
end
