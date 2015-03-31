module CukeSlicer
  class Slicer

    def slice(target, filters = {}, &block)
      validate_target(target)
      validate_filters(filters)


      begin
        target = File.directory?(target) ? CukeModeler::Directory.new(target) : CukeModeler::FeatureFile.new(target)
      rescue Gherkin::Lexer::LexingError
        raise(ArgumentError, "A syntax or lexing problem was encountered while trying to parse #{target}")
      end

      if target.is_a?(CukeModeler::Directory)
        sliced_tests = extract_test_cases_from_directory(target, filters, &block)
      else
        sliced_tests = extract_test_cases_from_file(target, filters, &block)
      end

      sliced_tests
    end

    def self.known_filters
      [:excluded_tags,
       :included_tags,
       :excluded_paths,
       :included_paths]
    end


    private


    def validate_target(target)
      raise(ArgumentError, "File or directory '#{target}' does not exist") unless File.exists?(target.to_s)
    end

    def validate_filters(filter_sets)
      filter_sets.each do |filter_type, filter_value|
        raise(ArgumentError, "Unknown filter '#{filter_type}'") unless self.class.known_filters.include?(filter_type)
        raise(ArgumentError, "Invalid filter '#{filter_value}'. Must be a String, Regexp, or Array thereof. Got #{filter_value.class}") unless filter_value.is_a?(String) or filter_value.is_a?(Regexp) or filter_value.is_a?(Array)

        if filter_value.is_a?(Array)
          validate_tag_collection(filter_value) if filter_type.to_s =~ /tag/
          validate_path_collection(filter_value) if filter_type.to_s =~ /path/
        end
      end
    end

    def validate_tag_collection(filter_collection)
      filter_collection.each do |filter|
        raise(ArgumentError, "Filter '#{filter}' must be a String, Regexp, or Array. Got #{filter.class}") unless filter.is_a?(String) or filter.is_a?(Regexp) or filter.is_a?(Array)

        validate_nested_tag_collection(filter) if filter.is_a?(Array)
      end
    end

    def validate_nested_tag_collection(filter_collection)
      filter_collection.each do |filter|
        raise(ArgumentError, "Tag filters cannot be nested more than one level deep.") if filter.is_a?(Array)
        raise(ArgumentError, "Filter '#{filter}' must be a String or Regexp. Got #{filter.class}") unless filter.is_a?(String) or filter.is_a?(Regexp)
      end
    end

    def validate_path_collection(filter_collection)
      filter_collection.each do |filter|
        raise(ArgumentError, "Filter '#{filter}' must be a String or Regexp. Got #{filter.class}") unless filter.is_a?(String) or filter.is_a?(Regexp)
      end
    end

    def extract_test_cases_from_directory(target, filters, &block)
      entries = Dir.entries(target.path)
      entries.delete '.'
      entries.delete '..'

      Array.new.tap do |test_cases|
        entries.each do |entry|
          entry = "#{target.path}/#{entry}"

          case
            when File.directory?(entry)
              test_cases.concat(extract_test_cases_from_directory(CukeModeler::Directory.new(entry), filters, &block))
            when entry =~ /\.feature$/
              test_cases.concat(extract_test_cases_from_file(CukeModeler::FeatureFile.new(entry), filters, &block))
            else
              # Non-feature files are ignored
          end
        end
      end
    end

    def extract_test_cases_from_file(target, filters, &block)
      Array.new.tap do |test_cases|
        unless target.feature.nil?
          tests = target.feature.tests

          runnable_elements = extract_runnable_elements(extract_runnable_block_elements(tests, filters))

          apply_custom_filter(runnable_elements, &block)

          runnable_elements.each do |element|
            test_cases << "#{element.get_ancestor(:feature_file).path}:#{element.source_line}"
          end
        end
      end
    end

    def extract_runnable_block_elements(things, filters)
      Array.new.tap do |elements|
        things.each do |thing|
          if thing.is_a?(CukeModeler::Outline)
            elements.concat(thing.examples)
          else
            elements << thing
          end
        end

        filter_excluded_paths(elements, filters[:excluded_paths])
        filter_included_paths(elements, filters[:included_paths])
        filter_excluded_tags(elements, filters[:excluded_tags])
        filter_included_tags(elements, filters[:included_tags])
      end
    end

    def extract_runnable_elements(things)
      Array.new.tap do |elements|
        things.each do |thing|
          if thing.is_a?(CukeModeler::Example)
            # Slicing in order to remove the parameter row element
            elements.concat(thing.row_elements.slice(1, thing.row_elements.count - 1))
          else
            elements << thing
          end
        end
      end
    end

    def apply_custom_filter(elements, &block)
      if block
        elements.reject! do |element|
          block.call(element)
        end
      end
    end

    def filter_excluded_tags(elements, filters)
      if filters
        filters = [filters] unless filters.is_a?(Array)

        unless filters.empty?
          elements.reject! do |element|
            matching_tag?(element, filters)
          end
        end
      end
    end

    def filter_included_tags(elements, filters)
      if filters
        filters = [filters] unless filters.is_a?(Array)

        elements.keep_if do |element|
          matching_tag?(element, filters)
        end
      end
    end

    def filter_excluded_paths(elements, filters)
      if filters
        filters = [filters] unless filters.is_a?(Array)

        elements.reject! do |element|
          matching_path?(element, filters)
        end
      end
    end

    def filter_included_paths(elements, filters)
      if filters
        filters = [filters] unless filters.is_a?(Array)

        unless filters.empty?
          elements.keep_if do |element|
            matching_path?(element, filters)
          end
        end
      end
    end

    def matching_tag?(element, filters)
      filters.each do |filter|
        if filter.is_a?(Array)
          filter_match = or_filter_match(element, filter)
        else
          filter_match = and_filter_match(element, filter)
        end

        return false unless filter_match
      end

      true
    end

    def and_filter_match(element, filter)
      filter_match(element, filter)
    end

    def or_filter_match(element, filters)
      filters.any? do |filter|
        filter_match(element, filter)
      end
    end

    def filter_match(element, filter)
      if filter.is_a?(Regexp)
        element.all_tags.any? { |tag| tag =~ filter }
      else
        element.all_tags.include?(filter)
      end
    end

    def matching_path?(element, filters)
      filters.any? do |filtered_path|
        if filtered_path.is_a?(Regexp)
          element.get_ancestor(:feature_file).path =~ filtered_path
        else
          element.get_ancestor(:feature_file).path == filtered_path
        end
      end
    end

  end
end
