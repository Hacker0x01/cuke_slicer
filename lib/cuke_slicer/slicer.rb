module CukeSlicer

  # The object responsible for slicing up a Cucumber test suite into discrete test cases.
  class Slicer

    # Slices up the given location into individual test cases.
    #
    # The location chosen for slicing can be a file or directory path. Optional filters can be provided in order to
    # ignore certain kinds of test cases. See #known_filters for the available option types. Most options are either a
    # string or regular expression, although arrays of the same can be given instead if more than one filter is desired.
    #
    # A block can be provided as a filter which can allow for maximal filtering flexibility. Note, however, that this
    # exposes the underlying modeling objects and knowledge of how they work is then required to make good use of the
    # filter.
    #
    # @param target [String] the location that will be sliced up
    # @param filters [Hash] the filters that will be applied to the sliced test cases
    def slice(target, filters = {}, &block)
      validate_target(target)
      filter_sets = filters.map {|k,v| FilterSet.new(k,v)}
      filter_sets.each(&:validate)


      begin
        target = File.directory?(target) ? CukeModeler::Directory.new(target) : CukeModeler::FeatureFile.new(target)
      rescue Gherkin::Lexer::LexingError
        raise(ArgumentError, "A syntax or lexing problem was encountered while trying to parse #{target}")
      end

      if target.is_a?(CukeModeler::Directory)
        sliced_tests = DirectoryExtractor.new(target, filters, &block).extract
      else
        sliced_tests = FileExtractor.new(target, filters, &block).extract
      end

      sliced_tests
    end

    # The filtering options that are currently supported by the slicer.
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

  end
end
