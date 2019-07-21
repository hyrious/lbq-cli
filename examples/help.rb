# lbq help [cmd]

params do
  option('--command', '--cmd', '-c', 'the command name', index: 0)
end

main do
  script_files = Dir.glob(File.expand_path '*.rb', __dir__)
  commands = script_files.map { |e| File.basename e, '.rb' }
  if params[:command].nil?
    puts <<~HINT
      Run "lbq #{File.basename __FILE__, '.rb'} [cmd]" to see script arguments' descriptions.
      Valid commands are:

      #{commands.map { |e| "    #{e}" }.join("\n")}
    HINT
  else
    cmd = params[:command]
    file = File.expand_path "#{cmd}.rb", __dir__
    if File.exist? file
      script = <<~RUBY
        def params
          puts
          yield if block_given?
        end

        def switch *args, default: false
          args = { '-' => [], '--' => [], '' => [] }.merge args.group_by { |s| s[/^-*/] }
          args[''].unshift "(default: \#{default})"
          until args.values.all?(&:empty?)
            first = args['-'].shift
            first = "\#{first}," if first
            printf "%5s %-22s %s\n", first, args['--'].shift, args[''].shift
          end
        end

        def option *args, default: nil, index: nil, type: String
          args = { '-' => [], '--' => [], '' => [] }.merge args.group_by { |s| s[/^-*/] }
          desc = []
          desc << "default: \#{default}" if default
          desc << "index: \#{index}"     if index
          desc << "type: \#{type}"       if type
          args[''].unshift "(\#{desc.join(', ')})"
          until args.values.all?(&:empty?)
            first = args['-'].shift
            first = "\#{first}," if first
            printf "%5s %-22s %s\n", first, args['--'].shift, args[''].shift
          end
        end

        def missing
        end

        def main
        end
      RUBY
      eval <<~RUBY, TOPLEVEL_BINDING.dup, file, -script.lines.size
        #{script}
        #{File.read file}
      RUBY
    else
      puts <<~NOTFOUND
        Not found command "#{cmd}".
      NOTFOUND
    end
  end
end
