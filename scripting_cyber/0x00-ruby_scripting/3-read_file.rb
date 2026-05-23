#!/usr/bin/env ruby

require 'json'

def count_user_ids(path)
  data = JSON.parse(File.read(path))
  
  user_id_counts = data.group_by { |entry| entry['userId'] }
                       .transform_values(&:count)
  
  user_id_counts.sort.each do |user_id, count|
    puts "#{user_id}: #{count}"
  end
end
