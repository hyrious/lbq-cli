
params do
  missing do |raw_str|
    @word = "#{@word} #{raw_str}"
  end
end

main do
  puts @word.reverse if @word
end
