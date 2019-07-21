
params do
  # switch/option([long_names][, short_names][, description][, options])
  # the program simply recognizes them by prefix '-'s
  switch('--switch', '--alias-switch', '-s', 'description', default: false)

  # if specified 'index:', you may pass this argument without '--name=',
  # $ lbq argv --arg=val
  # is the same as
  # $ lbq argv val
  option('--arg', 'line 1', 'line 2', index: 0)

  # options can have types
  # "Integer/Float/String" will result in calling Integer(value), etc.
  # or you can specify a proc to transform string input:
  # type: -> str { Date.parse str }
  option('--number', '-n', type: Integer)

  # unknown options/unexpected inputs will be passed to the missing block
  missing do |raw_str|
    puts "unknown input: #{raw_str}"
    (params[:unknown] ||= []) << raw_str
  end
end

main do
  pp params
  # -s --arg=1 -n=42 -v => {
  #   switch: true,
  #   alias_switch: true,
  #   s: true,
  #   arg: '1',
  #   number: 42,
  #   n: 42,
  #   unknown: ['-v']
  # }
end
