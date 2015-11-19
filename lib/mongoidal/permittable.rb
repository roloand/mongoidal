module Mongoidal
  module Permittable
    extend ActiveSupport::Concern

    def self.unpermitted_fields
      @unpermitted_fields ||= [:_id, :_type, :created_at, :updated_at]
    end

    module ClassMethods
      def unpermitted
        @unpermitted ||= Set.new.tap do |unpermitted|
          unpermitted.merge(Permittable.unpermitted_fields)
          self.ancestors.each do |ancestor|
            if ancestor != self and ancestor.respond_to? :unpermitted
              unpermitted.merge(ancestor.unpermitted)
            end
          end
        end
      end

      def unpermit(*fields)
        fields.each do |field|
          if field.respond_to? :name
            field = field.name.to_sym
          end

          unpermitted << field
        end
      end

      def permit_fields!(id: nil, embeds: true)
        permitted = []
        nested = {}
        fields = self.fields.keys.map(&:to_sym) - unpermitted.to_a
        fields.each do |field|
          type = self.fields[field.to_s].options[:type]
          if type == Array
            nested[field] = []
          else
            permitted << field
          end
        end

        # support embedded
        if embeds
          # if embeds is true
          if embeds == true
            # only select the embeds relations that have a permitted_fields method on their class
            embeds = self.relations.select do |k, v|
              # if id is nil, then we will auto-include it if this is an embedded document.
              if v.macro == :embedded_in
                id = true if id.nil?
              elsif !unpermitted.include?(k.to_sym)
                if v.macro == :embeds_one or v.macro == :embeds_many
                  v.class_name.to_const.respond_to?(:permitted_fields)
                end
              end

            end.map {|k, v| k}
          end

          embeds.each do |embed|
            permitted << embed
            nested[embed.to_sym] = self.relations[embed.to_s].class_name.to_const.permitted_fields
          end
        end

        permitted << :id if id
        permitted << nested if nested.present?

        self.define_singleton_method :permitted_fields do
          permitted
        end
      end
    end
  end
end