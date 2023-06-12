require 'surveyor/common'
require 'acts_as_list'

module Surveyor
  module Models
    module QuestionMethods
      extend ActiveSupport::Concern
      include ActiveModel::Validations
      include MustacheContext
      include ActiveModel::ForbiddenAttributesProtection

      included do

        # Associations
        belongs_to :survey_section, optional: true
        belongs_to :question_group, optional: true
        has_many :answers, :dependent => :destroy, inverse_of: :question # it might not always have answers
        has_one :dependency, :dependent => :destroy
        belongs_to :correct_answer, optional: true, :class_name => "Answer", :dependent => :destroy
        attr_accessible *PermittedParams.new.question_attributes if defined? ActiveModel::MassAssignmentSecurity

        acts_as_list scope: :survey_section_id, column: :display_order

        default_scope lambda{ order('questions.display_order ASC')}

        # Validations
        validates_presence_of :text
        validates_inclusion_of :is_mandatory, :in => [true, false]
      end

      # Instance Methods
      def initialize(*args)
        super(*args)
        default_args
      end

      def default_args
        self.is_mandatory ||= false
        self.display_type ||= "default"
        self.pick ||= "none"
        self.data_export_identifier ||= Surveyor::Common.normalize(text)
        self.short_text ||= text
        self.api_id ||= Surveyor::Common.generate_api_id
      end

      def pick=(val)
        write_attribute(:pick, val.nil? ? nil : val.to_s)
      end
      def display_type=(val)
        write_attribute(:display_type, val.nil? ? nil : val.to_s)
      end

      def mandatory?
        self.is_mandatory == true
      end

      def dependent?
        self.dependency != nil
      end
      def triggered?(response_set)
        dependent? ? self.dependency.is_met?(response_set) : true
      end
      def css_class(response_set)
        [(dependent? ? "q_dependent" : nil), (triggered?(response_set) ? nil : "q_hidden"), custom_class].compact.join(" ")
      end

      def part_of_group?
        !self.question_group.nil?
      end
      def solo?
        self.question_group.nil?
      end

      def multiple_choice_answer?
        self.pick == "any" || self.pick == "one"
      end

      def string_answer?
        self.pick == "none" && self.answers.first.response_class == "string"
      end

      def text_answer?
        self.pick == "none" && self.answers.first.response_class == "text"
      end

      def number_answer
        self.pick == "none" && self.answers.first.response_class == "float"
      end

      def text_for(position = nil, context = nil, locale = nil)
        return "" if display_type == "hidden_label"
        imaged(split(in_context(translation(locale)[:text], context), position))
      end
      def help_text_for(context = nil, locale = nil)
        in_context(translation(locale)[:help_text], context)
      end
      def split(text, position=nil)
        case position
          when :pre
            text.split("|",2)[0]
          when :post
            text.split("|",2)[1]
          else
            text
        end.to_s
      end
      def renderer(g = question_group)
        if self.display_type == "stars"
          self.display_type.to_sym
        else
          r = [g ? g.renderer.to_s : nil, display_type].compact.join("_")
          r.blank? ? :default : r.to_sym
        end
      end
      def translation(locale)
        {:text => self.text, :help_text => self.help_text}.with_indifferent_access.merge(
            (self.survey_section.survey.translation(locale)[:questions] || {})[self.reference_identifier] || {}
        )
      end

      private

      def imaged(text)
        self.display_type == "image" && !text.blank? ? ActionController::Base.helpers.image_tag(text, alt: File.basename(text, ".*").capitalize) : text
      end

    end
  end
end