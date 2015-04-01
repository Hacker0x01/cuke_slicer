require 'spec_helper'


describe 'Slicer, Integration' do

  let(:clazz) { CukeSlicer::Slicer }
  let(:slicer) { clazz.new }
  let(:test_file) { "#{@default_file_directory}/a_test.feature" }

  before(:each) do
    file_text = "Feature: Test feature

                   @tag
                   Scenario: Test scenario
                     * some step"

    File.open(test_file, 'w') { |file| file.write(file_text) }
  end


  describe 'slicing' do

    it 'slicing returns a collection of test cases' do
      slice_output = slicer.slice(test_file)

      expect(slice_output).to be_an(Array)
      expect(slice_output).to_not be_empty

      slice_output.each do |test_case|
        # Test cases come in 'file_path:line_number' format
        expect(test_case).to match(/^.+:\d+$/)
      end
    end

    it 'can slice without being provided filters' do
      expect { slicer.slice(test_file) }.to_not raise_error
    end

    it 'uses the custom filter, if provided' do
      expect { |test_block| slicer.slice(@default_file_directory, &test_block) }.to yield_control
      expect { slicer.slice(@default_file_directory) }.to_not raise_error
    end

    it 'can slice an empty feature file' do
      File.open(test_file, 'w') { |file| file.write('') }

      expect { slicer.slice(test_file) }.to_not raise_error
    end

    it 'can slice a feature that has no tests' do
      File.open(test_file, 'w') { |file| file.write('Feature: Empty feature') }

      expect { slicer.slice(test_file) }.to_not raise_error
    end

    it 'can slice a directory that contains non-feature files' do
      File.open("#{@default_file_directory}/not_a_feature.file", 'w') { |file| file.write('foobar') }

      expect { slicer.slice(@default_file_directory) }.to_not raise_error
    end


    describe 'target validation' do

      it 'complains if told to slice a non-existent location' do
        expect { slicer.slice('does/not/exist') }.to raise_error(ArgumentError, /does not exist/)
        expect { slicer.slice(nil) }.to raise_error(ArgumentError, /does not exist/)
      end

      it 'complains if told to slice an incorrectly formatted feature file' do
        File.open(test_file, 'w') { |file| file.write('foobar') }

        expect { slicer.slice(test_file) }.to raise_error(ArgumentError, /syntax.*lexing problem.*#{test_file}/i)
      end

    end

  end


  describe 'filtering' do

    it 'treats an empty filter set as if the filter were not provided' do
      filters = clazz.known_filters

      filters.each do |filter|
        not_provided = slicer.slice(test_file)

        case
          when filter.to_s =~ /path/
            nothing_provided = slicer.slice(test_file, filter => [])
          when filter.to_s =~ /tag/
            nothing_provided = slicer.slice(test_file, filter => [])
          else
            raise(ArgumentError, "Unknown filter '#{filter}'")
        end

        expect(nothing_provided).to eq(not_provided)
        expect(nothing_provided).to_not be_empty
      end
    end

    it 'can combine any and all filters' do
      filters = clazz.known_filters

      applied_filters = {excluded_tags: '@a',
                         included_tags: /./,
                         excluded_paths: 'a',
                         included_paths: /./}

      block_filter = eval("Proc.new { |test_case| false}")

      # A reminder to update this test if new filters are added in the future
      expect(applied_filters.keys).to match_array(filters)


      expect { @slice_output = slicer.slice(@default_file_directory, applied_filters, &block_filter) }.to_not raise_error
      expect(@slice_output).to be_an(Array)
      expect(@slice_output).to_not be_empty
    end


    describe 'filter validation' do

      it 'will only accept string, regular expression, or collections thereof as path filters' do
        path_filter_types = clazz.known_filters.select { |filter| filter.to_s =~ /path/ }

        path_filter_types.each do |filter|
          expect { slicer.slice(@default_file_directory, filter => '@some_value') }.to_not raise_error
          expect { slicer.slice(@default_file_directory, filter => /some_pattern/) }.to_not raise_error
          expect { slicer.slice(@default_file_directory, filter => ['@some_value', /some_pattern/]) }.to_not raise_error
          expect { slicer.slice(@default_file_directory, filter => :something_else) }.to raise_error(ArgumentError, /must be a/i)
          expect { slicer.slice(@default_file_directory, filter => [:something_else]) }.to raise_error(ArgumentError, /must be a/i)
        end
      end

      it 'will only accept strings, regular expressions, arrays, or collections thereof as tag filters' do
        tag_filter_types = clazz.known_filters.select { |filter| filter.to_s =~ /tag/ }

        tag_filter_types.each do |filter|
          expect { slicer.slice(@default_file_directory, filter => '@some_value') }.to_not raise_error
          expect { slicer.slice(@default_file_directory, filter => /some_pattern/) }.to_not raise_error
          expect { slicer.slice(@default_file_directory, filter => ['@some_value', /some_pattern/]) }.to_not raise_error
          expect { slicer.slice(@default_file_directory, filter => ['@some_value', [/nested_pattern/]]) }.to_not raise_error
          expect { slicer.slice(@default_file_directory, filter => ['@some_value', [/nested_pattern/, :bad_value]]) }.to raise_error(ArgumentError, /must be a/i)
          expect { slicer.slice(@default_file_directory, filter => :something_else) }.to raise_error(ArgumentError, /must be a/i)
          expect { slicer.slice(@default_file_directory, filter => [:something_else]) }.to raise_error(ArgumentError, /must be a/i)
        end
      end

      it 'will only accept a single level of tag filter nesting' do
        tag_filter_types = clazz.known_filters.select { |filter| filter.to_s =~ /tag/ }

        tag_filter_types.each do |filter|
          expect { slicer.slice(@default_file_directory, filter => ['@some_value', [/nested_pattern/]]) }.to_not raise_error
          expect { slicer.slice(@default_file_directory, filter => ['@some_value', [/nested_pattern/, ['way_too_nested']]]) }.to raise_error(ArgumentError, /cannot.* nested/i)
        end
      end

      it 'complains if given an unknown filter' do
        unknown_filter_type = :unknown_filter
        options = {unknown_filter_type => 'foo'}

        expect { slicer.slice(@default_file_directory, options) }.to raise_error(ArgumentError, /unknown filter.*#{unknown_filter_type}/i)
      end

    end

  end

end
