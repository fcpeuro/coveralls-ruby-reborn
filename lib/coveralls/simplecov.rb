require 'pathname'

module Coveralls
  module SimpleCov
    class Formatter
      def display_result(result)
        # Log which files would be submitted.
        if !result.files.empty?
          Coveralls::Output.puts '[Coveralls] Some handy coverage stats:'
        else
          Coveralls::Output.puts '[Coveralls] There are no covered files.', color: 'yellow'
        end
        result.files.each do |f|
          Coveralls::Output.print '  * '
          Coveralls::Output.print short_filename(f.filename).to_s, color: 'cyan'
          Coveralls::Output.print ' => ', color: 'white'
          cov = "#{f.covered_percent.round}%"
          if f.covered_percent > 90
            Coveralls::Output.print cov, color: 'green'
          elsif f.covered_percent > 80
            Coveralls::Output.print cov, color: 'yellow'
          else
            Coveralls::Output.print cov, color: 'red'
          end
          Coveralls::Output.puts ''
        end
        true
      end

      def get_source_files(result)
        # Gather the source files.
        source_files = []
        result.files.each do |file|
          properties = {}

          # Get Source
          properties[:source] = File.open(file.filename, 'rb:utf-8').read

          # Get the root-relative filename
          properties[:name] = short_filename(file.filename)

          # Get the coverage
          properties[:coverage] = file.coverage.dup

          # Skip nocov lines
          file.lines.each_with_index do |line, i|
            properties[:coverage][i] = nil if line.skipped?
          end

          source_files << properties
        end
        source_files
      end

      def format(result)
        unless Coveralls.should_run?
          display_result result if Coveralls.noisy?

          return
        end

        # Post to Coveralls.
        API.post_json 'jobs',
                      source_files: get_source_files(result),
                      test_framework: result.command_name.downcase,
                      run_at: result.created_at

        Coveralls::Output.puts output_message result

        true

      rescue Exception => error
        display_error error
      end

      def display_error(error)
        Coveralls::Output.puts 'Coveralls encountered an exception:', color: 'red'
        Coveralls::Output.puts error.class.to_s, color: 'red'
        Coveralls::Output.puts error.message, color: 'red'
        error.backtrace&.each do |line|
          Coveralls::Output.puts line, color: 'red'
        end
        if error.respond_to?(:response) && error.response
          Coveralls::Output.puts error.response.to_s, color: 'red'
        end
        false
      end

      def output_message(result)
        "Coverage is at #{result.covered_percent.round(2) rescue result.covered_percent.round}%.\nCoverage report sent to Coveralls."
      end

      def short_filename(filename)
        return filename unless ::SimpleCov.root

        filename = Pathname.new(filename)
        root = Pathname.new(::SimpleCov.root)
        filename.relative_path_from(root).to_s
      end
    end
  end
end
