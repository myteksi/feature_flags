require 'spec_helper'

describe FeatureFlagsGeneral::FlagAccessor do
  let(:redis) { double() }

  describe 'global feature accessor' do
    let(:flagAccessor) do
      storage = FeatureFlagsGeneral::FlagStorage.new(redis, namespace: 'features')
      FeatureFlagsGeneral::FlagAccessor.new(storage, :city, 9, features: %i(cashless grab_car))
    end

    [:cashless?, :grab_car?, :cashless=, :grab_car=].each do |method|
      it "responds to #{method}" do
        expect(flagAccessor.respond_to?(method)).to be(true)
      end
    end

    [:cashless_in_city?, :grab_car_in_city?].each do |method|
      it "not responds to #{method}" do
        expect(flagAccessor.respond_to?(method)).to be(false)
      end
    end

    [:cashless?, :grab_car?].each do |method|
      it "#{method} is false" do
        allow(redis).to receive(:sismember).and_return(false)
        expect(flagAccessor.send(method)).to be(nil)
      end

      it "#{method} is true" do
        allow(redis).to receive(:sismember).and_return(true)
        expect(flagAccessor.send(method)).to be(:live)
      end
    end

    it 'get features :live' do
      allow(redis).to receive(:sismember).and_return(true)
      expect(flagAccessor.features).to match({ cashless: :live, grab_car: :live })
    end

    it 'get features nil' do
      allow(redis).to receive(:sismember).and_return(false)
      expect(flagAccessor.features).to match({ cashless: nil, grab_car: nil })
    end

    it 'set feature to live' do
      expect(redis).to receive(:sadd).with('features_state_cashless_live_city', 9).once
      expect(redis).to receive(:srem).with('features_state_cashless_beta_city', 9).once

      flagAccessor.cashless = :live
    end

    it 'set feature to beta' do
      expect(redis).to receive(:sadd).with('features_state_cashless_beta_city', 9).once
      expect(redis).to receive(:srem).with('features_state_cashless_live_city', 9).once

      flagAccessor.cashless = :beta
    end

    it 'set feature to nil' do
      expect(redis).to receive(:srem).with('features_state_grab_car_beta_city', 9).once
      expect(redis).to receive(:srem).with('features_state_grab_car_live_city', 9).once

      flagAccessor.grab_car = nil
    end
  end

  describe 'local feature accessor' do
    let(:flagAccessor) do
      storage = FeatureFlagsGeneral::FlagStorage.new(redis, namespace: 'features')
      FeatureFlagsGeneral::FlagAccessor.new(storage, :user, 1, features: %i(cashless grab_car), global_key: :city)
    end

    [:cashless?, :grab_car?, :cashless_in_city?, :grab_car_in_city?, :cashless=, :grab_car=].each do |method|
      it "responds to #{method}" do
        expect(flagAccessor.respond_to?(method)).to be(true)
      end
    end

    [:cashless?, :grab_car?].each do |method|
      it "#{method} is false" do
        allow(redis).to receive(:sismember).and_return(false)
        expect(flagAccessor.send(method)).to be(nil)
      end

      it "#{method} is true" do
        allow(redis).to receive(:sismember).and_return(true)
        expect(flagAccessor.send(method)).to be(:whitelist)
      end
    end

    [:cashless_in_city?, :grab_car_in_city?].each do |method|
      it "#{method} is false" do
        allow(redis).to receive(:sismember).and_return(false)
        expect(flagAccessor.send(method, 2)).to be(false)
      end

      it "#{method} is true" do
        allow(redis).to receive(:sismember).and_return(true)
        expect(flagAccessor.send(method, 2)).to be(true)
      end
    end

    it 'get features :whitelist' do
      allow(redis).to receive(:sismember).and_return(true)
      expect(flagAccessor.features).to match({ cashless: :whitelist, grab_car: :whitelist })
    end

    it 'get features nil' do
      allow(redis).to receive(:sismember).and_return(false)
      expect(flagAccessor.features).to match({ cashless: nil, grab_car: nil })
    end

    it 'get feature?' do
      allow(redis).to receive(:sismember).and_return(true)
      expect(flagAccessor.features_in_city?(9)).to match({ cashless: true, grab_car: true })
    end

    it 'set feature to whitelist' do
      expect(redis).to receive(:sadd).with('features_list_cashless_whitelist_user', 1).once
      expect(redis).to receive(:srem).with('features_list_cashless_blacklist_user', 1).once

      flagAccessor.cashless = :whitelist
    end

    it 'set feature to blacklist' do
      expect(redis).to receive(:sadd).with('features_list_grab_car_blacklist_user', 1).once
      expect(redis).to receive(:srem).with('features_list_grab_car_whitelist_user', 1).once

      flagAccessor.grab_car = :blacklist
    end

    it 'set feature to nil' do
      expect(redis).to receive(:srem).with('features_list_cashless_whitelist_user', 1).once
      expect(redis).to receive(:srem).with('features_list_cashless_blacklist_user', 1).once

      flagAccessor.cashless = nil
    end
  end
end
