# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/expect_base'
require 'transpec/syntax/mixin/have_matcher_owner'

module Transpec
  class Syntax
    class Expect < Syntax
      include Mixin::ExpectBase, Mixin::HaveMatcherOwner

      def self.target_method?(receiver_node, method_name)
        receiver_node.nil? && [:expect, :expect_any_instance_of].include?(method_name)
      end

      def any_instance?
        method_name == :expect_any_instance_of
      end
    end
  end
end
