
# simple test of retry logic in rescue
RETRIES = 3

def test_it(try: 1)
  begin
    puts try
    raise "Raised"
    return "never get here"
  rescue
    puts "Retry attempt #{try} in #{2**(try-1)} seconds...."
    sleep 2**(try-1);
    return test_it(try: try + 1) if try < RETRIES

    puts "...#{try} failed!"
    raise "Failed after 3"
  ensure
    puts "printing from ensure #{try}"
  end
end

result = test_it

puts "Result was #{result}"
