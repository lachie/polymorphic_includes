# PolymorphicIncludeHints

module Smartbomb
  module PolymorphicIncludes
  
    def self.included(base)
      base.extend(ClassMethods)
    end
  
    module ClassMethods
      # monkeypatch for allowing polymorphic include hints
      # TODO add tests
      def preload_belongs_to_association(records, reflection, preload_options={})      
        options = reflection.options
        primary_key_name = reflection.primary_key_name

        # make includes take the reflection's include by default
        klass_includes = Hash.new {|hash,key| hash[key] = options[:include]}

        if options[:polymorphic]
          polymorph_type = options[:foreign_type]
          klasses_and_ids = {}

          klass_include_options   = if options[:polymorphic].is_a?(Hash) then options[:polymorphic][:class_includes] end
          klass_include_options ||= {}


          # Construct a mapping from klass to a list of ids to load and a mapping of those ids back to their parent_records
          records.each do |record|
            if klass = record.send(polymorph_type)
              klass_include = klass_include_options[klass]
              if klass_include
                klass_includes[klass] = klass_include
              end

              klass_id = record.send(primary_key_name)
              if klass_id
                id_map = klasses_and_ids[klass] ||= {}
                id_list_for_klass_id = (id_map[klass_id.to_s] ||= [])
                id_list_for_klass_id << record
              end
            end
          end

          klasses_and_ids = klasses_and_ids.to_a
        else
          id_map = {}
          records.each do |record|
            key = record.send(primary_key_name)
            if key
              mapped_records = (id_map[key.to_s] ||= [])
              mapped_records << record
            end
          end

          klasses_and_ids = [[reflection.klass.name, id_map]]
        end

        klasses_and_ids.each do |klass_and_id|
          klass_name, id_map = *klass_and_id
          klass = klass_name.constantize

          table_name = klass.quoted_table_name
          primary_key = klass.primary_key
          column_type = klass.columns.detect{|c| c.name == primary_key}.type
          ids = id_map.keys.uniq.map do |id|
            if column_type == :integer
              id.to_i
            elsif column_type == :float
              id.to_f
            else
              id
            end
          end

          conditions = "#{table_name}.#{connection.quote_column_name(primary_key)} #{in_or_equals_for_ids(ids)}"
          conditions << append_conditions(reflection, preload_options)

          associated_records = klass.find(:all, :conditions => [conditions, ids],
                                          :include => klass_includes[klass_name],
                                          :select => options[:select],
                                          :joins => options[:joins],
                                          :order => options[:order])

          set_association_single_records(id_map, reflection.name, associated_records, primary_key)
        end
      end
    end
  end
end