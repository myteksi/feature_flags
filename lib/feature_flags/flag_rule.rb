module FeatureFlagsGeneral
  class FlagRule
    # states, lists are arrays of acceptable values
    attr_accessor :states, :lists
    # feature_checker is a Proc/Lambda/Class that respond_to `call(state, list)`
    # it should return true if the combination is feature activated
    attr_accessor :feature_checker
    # key_generator is a Proc/Lambda/Class that respond_to `call(state, list)`
    attr_accessor :key_generator
  end
end
