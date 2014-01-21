# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/expectizable'
require 'transpec/syntax/mixin/monkey_patch_any_instance'
require 'transpec/syntax/mixin/allow_no_message'
require 'transpec/syntax/mixin/any_instance_block'

module Transpec
  class Syntax
    class ShouldReceive < Syntax
      include Mixin::Expectizable, Mixin::MonkeyPatchAnyInstance, Mixin::AnyInstanceBlock,
              Mixin::AllowNoMessage

      alias_method :useless_expectation?, :allow_no_message?

      def self.target_method?(receiver_node, method_name)
        !receiver_node.nil? && [:should_receive, :should_not_receive].include?(method_name)
      end

      add_dynamic_analysis_request do |rewriter|
        register_request_of_syntax_availability_inspection(
          rewriter,
          :expect_to_receive_available?,
          [:expect, :receive]
        )

        register_request_of_syntax_availability_inspection(
          rewriter,
          :allow_to_receive_available?,
          [:allow, :receive]
        )
      end

      def expect_to_receive_available?
        check_syntax_availability(__method__)
      end

      def allow_to_receive_available?
        check_syntax_availability(__method__)
      end

      def positive?
        method_name == :should_receive
      end

      def expectize!(negative_form = 'not_to')
        unless expect_to_receive_available?
          fail ContextError.new(selector_range, "##{method_name}", '#expect')
        end

        convert_to_syntax!('expect', negative_form)
        register_record(ExpectRecord, negative_form)
      end

      def allowize_useless_expectation!(negative_form = 'not_to')
        return unless useless_expectation?

        unless allow_to_receive_available?
          fail ContextError.new(selector_range, "##{method_name}", '#allow')
        end

        convert_to_syntax!('allow', negative_form)
        remove_allowance_for_no_message!

        register_record(AllowRecord, negative_form)
      end

      def stubize_useless_expectation!
        return unless useless_expectation?

        replace(selector_range, 'stub')
        remove_allowance_for_no_message!

        register_record(StubRecord)
      end

      def add_receiver_arg_to_any_instance_implementation_block!
        super && register_record(AnyInstanceBlockRecord)
      end

      private

      def convert_to_syntax!(syntax, negative_form)
        if any_instance?
          wrap_subject_with_any_instance_of!(syntax)
        else
          wrap_subject_with_method!(syntax)
        end

        replace(selector_range, "#{positive? ? 'to' : negative_form} receive")

        correct_block_style!
      end

      def correct_block_style!
        return if broken_block_nodes.empty?

        broken_block_nodes.each do |block_node|
          map = block_node.loc
          next if map.begin.source == '{'
          replace(map.begin, '{')
          replace(map.end, '}')
        end
      end

      def wrap_subject_with_any_instance_of!(syntax)
        expression = "#{syntax}_any_instance_of(#{any_instance_target_class_source})"
        replace(subject_range, expression)
      end

      def broken_block_nodes
        @broken_block_nodes ||= [
          block_node_taken_by_with_method_with_no_normal_args,
          block_node_following_message_expectation_method
        ].compact.uniq
      end

      # subject.should_receive(:method_name).once.with do |block_arg|
      # end
      #
      # (block
      #   (send
      #     (send
      #       (send
      #         (send nil :subject) :should_receive
      #         (sym :method_name)) :once) :with)
      #   (args
      #     (arg :block_arg)) nil)
      def block_node_taken_by_with_method_with_no_normal_args
        each_chained_method_node do |chained_node, child_node|
          next unless chained_node.block_type?
          return nil unless child_node.children[1] == :with
          return nil if child_node.children[2]
          return chained_node
        end
      end

      # subject.should_receive(:method_name) do |block_arg|
      # end.once
      #
      # (send
      #   (block
      #     (send
      #       (send nil :subject) :should_receive
      #       (sym :method_name))
      #     (args
      #       (arg :block_arg)) nil) :once)
      def block_node_following_message_expectation_method
        each_chained_method_node do |chained_node, child_node|
          next unless chained_node.send_type?
          return child_node if child_node.block_type?
        end
      end

      def register_record(record_class, negative_form_of_to = nil)
        @report.records << record_class.new(self, negative_form_of_to)
      end

      class ExpectRecord < Record
        def initialize(should_receive, negative_form_of_to)
          @should_receive = should_receive
          @negative_form_of_to = negative_form_of_to
        end

        def original_syntax
          syntax = if @should_receive.any_instance?
                     'Klass.any_instance.'
                   else
                     'obj.'
                   end
          syntax << "#{@should_receive.method_name}(:message)"
        end

        def converted_syntax
          syntax = if @should_receive.any_instance?
                     'expect_any_instance_of(Klass).'
                   else
                     'expect(obj).'
                   end
          syntax << (@should_receive.positive? ? 'to' : @negative_form_of_to)
          syntax << ' receive(:message)'
        end
      end

      class AllowRecord < Record
        def initialize(should_receive, negative_form_of_to)
          @should_receive = should_receive
          @negative_form_of_to = negative_form_of_to
        end

        def original_syntax
          syntax = if @should_receive.any_instance?
                     'Klass.any_instance.'
                   else
                     'obj.'
                   end
          syntax << "#{@should_receive.method_name}(:message)"
          syntax << '.any_number_of_times' if @should_receive.any_number_of_times?
          syntax << '.at_least(0)' if @should_receive.at_least_zero?
          syntax
        end

        def converted_syntax
          syntax = if @should_receive.any_instance?
                     'allow_any_instance_of(Klass).'
                   else
                     'allow(obj).'
                   end
          syntax << (@should_receive.positive? ? 'to' : @negative_form_of_to)
          syntax << ' receive(:message)'
        end
      end

      class StubRecord < Record
        def initialize(should_receive, *)
          @should_receive = should_receive
        end

        def original_syntax
          syntax = "obj.#{@should_receive.method_name}(:message)"
          syntax << '.any_number_of_times' if @should_receive.any_number_of_times?
          syntax << '.at_least(0)' if @should_receive.at_least_zero?
          syntax
        end

        def converted_syntax
          'obj.stub(:message)'
        end
      end

      class AnyInstanceBlockRecord < Record
        def initialize(should_receive, *)
          @should_receive = should_receive
        end

        def original_syntax
          "Klass.any_instance.#{@should_receive.method_name}(:message) { |arg| }"
        end

        def converted_syntax
          "Klass.any_instance.#{@should_receive.method_name}(:message) { |instance, arg| }"
        end
      end
    end
  end
end
