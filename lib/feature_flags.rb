class FeatureFlags
  def initialize(redis, namespace, group_size = 100_000)
    @feature_flags = FeatureFlagsGeneral::FlagStorage.new(redis, namespace: 'flags') do |rule|
      rule.states = %i(beta live)
      rule.lists = %i(whitelist blacklist)

      rule.feature_checker = ->(state, list) do
        return true if :live == state && :blacklist != list
        return true if :beta == state && :whitelist == list

        false
      end

      rule.key_generator = ->(type, feature_key, feature, state, feature_val) do
        parts = [feature_key, feature, state]
        parts << feature_val % group_size if state == :la
        parts.join('_'.freeze)
      end
    end

    @redis = redis
    @namespace = namespace
    @group_size = group_size
  end

  # cashless_live: [1, 2, 3] # cashless_beta: [4, 5, 6]
  def activate_city(feature:, city_id:, live: false)
    return if city_id.nil? || feature.nil?

    @feature_flags.set_global_feature(:city, city_id, feature.to_sym, live ? :live : :beta)

#     if live
#       @redis.sadd(live_features_key(feature), city_id)
#       @redis.srem(beta_features_key(feature), city_id)
#     else
#       @redis.sadd(beta_features_key(feature), city_id)
#       @redis.srem(live_features_key(feature), city_id)
#     end
  end

  # Neither live / beta
  def deactivate_city(feature:, city_id:)
    return if feature.nil? || city_id.nil?

    @redis.srem(live_features_key(feature), city_id)
    @redis.srem(beta_features_key(feature), city_id)
  end

  def city_state(feature:, city_id:)
    return nil if feature.nil? || city_id.nil?

    if city_live?(feature: feature, city_id: city_id)
      'live'
    elsif city_beta?(feature: feature, city_id: city_id)
      'beta'
    else
      'inactive'
    end
  end

  # Returns a hash as follows { cashless: 'live', beta: nil, something: 'beta' }
  def city_features(city_id: , feature_list: [])
    features = {}
    feature_list.each do |feature|
      if city_live?(feature: feature, city_id: city_id)
        features[feature] = 'live'
      elsif city_beta?(feature: feature, city_id: city_id)
        features[feature] = 'beta'
      else
        features[feature] = nil
      end
    end

    features
  end

  def activate_user(feature:, city_id:, id:)
    if city_beta?(feature: feature, city_id: city_id)
      @redis.sadd(whitelist_user_key(feature), id)
      @redis.srem(blacklist_user_key(feature, id), id)
    else
      @redis.srem(blacklist_user_key(feature, id), id)
      @redis.srem(whitelist_user_key(feature), id)
    end
  end

  def deactivate_user(feature:, id:)
    @redis.sadd(blacklist_user_key(feature, id), id)
    @redis.srem(whitelist_user_key(feature), id)
  end

  def user_active_in_city?(feature:, city_id:, id:)
    return false if feature.nil? || city_id.nil? || id.nil?

    if city_live?(feature: feature, city_id: city_id)
      !@redis.sismember(blacklist_user_key(feature, id), id)
    elsif city_beta?(feature: feature, city_id: city_id)
      @redis.sismember(whitelist_user_key(feature), id)
    else
      false
    end
  end

  def user_state(feature:, id:)
    return nil if feature.nil? || id.nil?

    # If both should return 'beta'.
    if @redis.sismember(whitelist_user_key(feature), id)
      return 'beta'
    elsif !@redis.sismember(blacklist_user_key(feature, id), id)
      return 'live'
    else
      return 'inactive'
    end
  end

  # Returns a hash as follows { cashless: 'live', beta: nil, something: 'beta' }
  def user_features(id:, city_id:, feature_list: [])
    features = {}
    feature_list.each do |feature|
      if user_active_in_city?(feature: feature, city_id: city_id, id: id)
        features[feature] = true
      else
        features[feature] = false
      end
    end

    features
  end

  private

  def city_live?(feature:, city_id:)
   @redis.sismember(live_features_key(feature), city_id)
  end

  def city_beta?(feature:, city_id:)
    @redis.sismember(beta_features_key(feature), city_id)
  end

  def live_features_key(feature)
    "#{@namespace}_city_#{feature}_live"
  end

  def beta_features_key(feature)
    "#{@namespace}_city_#{feature}_beta"
  end

  def blacklist_user_key(feature, id)
    "#{@namespace}_user_#{feature}_blacklist_#{id / @group_size}"
  end

  def whitelist_user_key(feature)
    "#{@namespace}_user_#{feature}_whitelist"
  end
end
