# require "lbq/cli/version"

module Lbq
  module Cli
    class NotFoundError < StandardError
      attr_reader :cmd
      def initialize cmd=nil
        @cmd = cmd
        msg = "Not found #{cmd ? "\"#{cmd}\"" : "such command"}"
        super msg
      end
    end

    module Vocab
      module_function

      def win?
        Gem.win_platform?
      end

      def touch
        win? ? 'type nul >>' : 'touch'
      end

      def prompt
        win? ? "#{backslash Dir.home}>" : '$ '
      end

      def path str
        ret = File.expand_path str
        ret = backslash ret if win?
        ret
      end

      def paths
        ret = ENV['PATH']
        ret = ret && ret.split(File::PATH_SEPARATOR)
        ret = ret || %w[/usr/local/bin /usr/ucb /usr/bin /bin]
        ret.select { |path| Dir.exist? path }
      end

      def exts
        ret = ENV['PATHEXT']
        ret = ret && ret.split(File::PATH_SEPARATOR)
        ret || ['']
      end

      def which cmd
        paths.each do |path|
          exts.each do |ext|
            exe = File.join(path, "#{cmd}#{ext}")
            if File.executable? exe
              return self.path exe
            end
          end
        end
        nil
      end

      def editor
        editors = win? ? %w[subl code notepad] : %w[vim vi emacs nano]
        editors.each do |exe|
          return exe if which exe
        end
        'EDITOR'
      end

      def backslash str
        str.tr '/', '\\'
      end
    end

    V = Vocab

    module_function

    def need_init?
      !Dir.exist? V.path '~/lbq'
    end

    def copy_file from, to
      File.open from do |f|
        File.open to, 'wb', f.stat.mode do |t|
          IO.copy_stream f, t
        end
      end
    end

    def init_example_scripts
      files = Dir.glob File.expand_path '../../examples/*', __dir__
      dist = File.expand_path '~/lbq'
      Dir.mkdir dist unless Dir.exist? dist
      files.each do |file|
        copy_file file, File.join(dist, File.basename(file))
      end
      puts <<~HINT
        Example scripts are placed at #{V.path '~/lbq'},
        check them for quick getting started.

      HINT
    end

    # execute 'cmd', '--arg=42', '-a', '--switch'
    def execute cmd='help', *args
      init_example_scripts if need_init?
      raise NotFoundError, cmd unless exist? cmd
      load_script cmd, *args
    rescue NotFoundError => e
      puts <<~HINT
        Run command below to create [#{e.cmd}],

            #{V.prompt}#{V.touch} #{V.path "~/lbq/#{e.cmd}.rb"}
            #{V.prompt}#{V.editor} #{V.path "~/lbq/#{e.cmd}.rb"}

        Notice "#{V.prompt}" is the prompt and you don't have to type it.
      HINT
    end

    def exist? cmd
      File.exist? File.expand_path "~/lbq/#{cmd}.rb"
    end

    def load_script cmd, *argv
      filename = File.expand_path "~/lbq/#{cmd}.rb"
      script = <<~RUBY
        ARGV.clear.push *#{argv.inspect}

        def arg2key arg
          (arg.start_with?('--') ? arg[2..-1].tr('-', '_') : arg[1..-1]).to_sym
        end

        def typed value, type=String
          case
          when type == String
            String(value)
          when type == Integer
            Integer(value)
          when type == Float
            Float(value)
          when type.respond_to?(:call)
            type.call(value)
          else
            # unknown type
            value
          end
        end

        def params
          @params ||= {}
          if block_given?
            yield
            @default_options.each do |index, (args, type)|
              if value = ARGV[index]
                value = typed value, type
                args.each do |arg|
                  key = arg2key arg
                  params[key] = value
                end
                ARGV[index] = nil
              end
            end if @default_options
            ARGV.compact!
            ARGV.each { |arg| @missing.call arg } if @missing.respond_to? :call
          end
          @params
        end

        def switch *args, default: false
          args = args.select { |arg| arg.start_with? '-' }
          if args.any? { |arg| (i = ARGV.index arg) and (ARGV.delete_at i) }
            args.each do |arg|
              key = arg2key arg
              params[key] = !default
            end
            !default
          else
            default
          end
        end

        def option *args, default: nil, index: nil, type: String
          raw_str = ''
          args = args.select { |arg| arg.start_with? '-' }
          args.each do |arg|
            key = arg2key arg
            params[key] = default
          end if default
          if args.any? { |arg| (i = ARGV.index { |a| a.start_with? "\#{arg}=" }) and (raw_str = ARGV.delete_at i) }
            value = typed (raw_str.split('=')[1] || default), type
            args.each do |arg|
              key = arg2key arg
              params[key] = value
            end
            value
          elsif args.any? { |arg| (i = ARGV.index arg) and ARGV[i + 1] and ARGV[i + 1][0] != '-' and (ARGV.delete_at i) and (raw_str = ARGV.delete_at i) }
            value = typed (raw_str || default), type
            args.each do |arg|
              key = arg2key arg
              params[key] = value
            end
            value
          elsif index
            @default_options ||= {}
            @default_options[index] = [args, type]
          else
            nil
          end
        end

        def missing &blk
          @missing = blk
        end

        def main
          yield
        end
      RUBY
      eval <<~RUBY, TOPLEVEL_BINDING.dup, filename, -script.lines.size
        #{script}
        #{File.read filename}
      RUBY
    end
  end
end
