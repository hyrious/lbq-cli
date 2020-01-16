require "fileutils"
require_relative "cli/version"

module Lbq
  module Cli
    VERBOSE = false

    def self.plugins
      @plugins ||= {}
    end

    def self.init(folder)
      Dir.mkdir folder
    rescue SystemCallError
      puts $!
    end

    def self.execute(*argv)
      folder = File.join Dir.home, "lbq"
      init folder unless Dir.exist? folder
      pattern = File.join folder, "*.rb"
      Dir.glob(pattern) { |file| load file }
      argv.size.downto 1 do |n|
        plugins.each do |seq, blk|
          zipper = argv[0, n].zip(seq)
          if zipper.all? { |a, p| p === a }
            blk.call(*zipper.map { |a, p| p.match(a) })
            return
          end
        end
      end
      puts 'Put scripts to ~/lbq/*.rb, example:', <<~RUBY
        require 'lbq/cli'
        R 'test' do
          puts 'Hello, world!'
        end
      RUBY
    end

    def R(*seq, &blk)
      pattern = seq.map(&:inspect).join(" ")
      if Cli.plugins[seq]
        source = Cli.plugins[seq].source_location.join(':')
        puts "Override: #{pattern}, previous is at #{source}"
      end
      Cli.plugins[seq] = blk
      puts "Loaded: #{pattern}" if VERBOSE
      return seq
    end
  end
end

extend Lbq::Cli
