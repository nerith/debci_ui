module Debci

  # This class contains provides a Ruby interface to read debci configuration
  # values.
  #
  # Available configuration items:
  #
  # * +data_basedir+: the root directory used by debci to store test run data
  #
  # There is a globally accessible instance of this class accessible from the
  # +config+ method of the Debci module.
  #
  #     >> Debci.config.data_basedir
  #     => "/path/to/debci/data"
  #
  class Config < Struct.new(:data_basedir)

    # for development usage
    if !system('which debci >/dev/null')
      bin = File.dirname(__FILE__) + '/../../bin'
      if File.exists?(bin)
        ENV['PATH'] = [bin,ENV['PATH']].join(':')
      end
    end

    def initialize
      # :nodoc:
      IO.popen(['debci', 'config', *members.map(&:to_s)]) do |data|
        data.each_line.each do |line|
          key, value = line.strip.split('=')
          self.send("#{key}=", value)
        end
      end
    end

  end

end
