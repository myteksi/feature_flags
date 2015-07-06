class FeatureFlags
  def initialize(redis)
    @redis  = redis
  end

  # cashless_live: [1, 2, 3] # cashless_beta: [4, 5, 6]
  def activate_city(feature:, city_id:, live: false)
    return if city_id.nil? || feature.nil?

    if live
      @redis.sadd(live_features_key(feature), city_id)
      @redis.srem(beta_features_key(feature), city_id)
    else
      @redis.sadd(beta_features_key(feature), city_id)
      @redis.srem(live_features_key(feature), city_id)
    end
  end

  # Neither live / beta
  def deactivate_city(feature:, city_id:)
    return if feature.nil? || city_id.nil?

    @redis.srem(live_features_key(feature), city_id)
    @redis.srem(beta_features_key(feature), city_id)
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
    if city_live?(feature: feature, city_id: city_id)
      @redis.srem(blacklist_user_key(feature, id), id)
    elsif city_beta?(feature: feature, city_id: city_id)
      @redis.sadd(whitelist_user_key(feature), id)
    end
  end

  def deactivate_user(feature:, city_id:, id:)
    if city_live?(feature: feature, city_id: city_id)
      @redis.sadd(blacklist_user_key(feature, id), id)
    elsif city_beta?(feature: feature, city_id: city_id)
      @redis.srem(whitelist_user_key(feature), id)
    end
  end

  def user_active?(feature:, city_id:, id:)
    return false if feature.nil? || city_id.nil? || id.nil?

    if city_live?(feature: feature, city_id: city_id)
      !@redis.sismember(blacklist_user_key(feature, id), id)
    elsif city_beta?(feature: feature, city_id: city_id)
      @redis.sismember(whitelist_user_key(feature), id)
    else
      false
    end
  end

  # Returns a hash as follows { cashless: 'live', beta: nil, something: 'beta' }
  def user_features(id:, city_id:, feature_list: [])
    features = {}
    feature_list.each do |feature|
      if user_active?(feature: feature, city_id: city_id, id: id)
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
    "city_#{feature}_live"
  end

  def beta_features_key(feature)
    "city_#{feature}_beta"
  end

  def blacklist_user_key(feature, id)
    "user_#{feature}_blacklist_#{id / 1000}"
  end

  def whitelist_user_key(feature)
    "user_#{feature}_whitelist"
  end
end
