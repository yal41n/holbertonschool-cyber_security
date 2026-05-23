#!/usr/bin/env ruby
require 'optparse'

TASKS_FILE = 'tasks.txt'
options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: cli.rb [options]"

  opts.on('-a TASK', '--add TASK', 'Add a new task') do |task|
    options[:add] = task
  end

  opts.on('-l', '--list', 'List all tasks') do
    options[:list] = true
  end

  opts.on('-r INDEX', '--remove INDEX', 'Remove a task by index') do |index|
    options[:remove] = index.to_i
  end

  opts.on('-h', '--help', 'Show help') do
    puts opts
    exit
  end
end.parse!

# Add a task
if options[:add]
  File.open(TASKS_FILE, 'a') { |f| f.puts(options[:add]) }
  puts "Task '#{options[:add]}' added."
end

# List all tasks
if options[:list]
  if File.exist?(TASKS_FILE)
    puts "Tasks:"
    File.readlines(TASKS_FILE).each_with_index do |task, i|
      puts "#{i + 1}. #{task.strip}"
    end
  else
    puts "No tasks found."
  end
end

# Remove a task
if options[:remove]
  if File.exist?(TASKS_FILE)
    tasks = File.readlines(TASKS_FILE).map(&:strip)
    if options[:remove].between?(1, tasks.length)
      removed = tasks.delete_at(options[:remove] - 1)
      File.write(TASKS_FILE, tasks.join("\n") + "\n")
      puts "Task '#{removed}' removed."
    else
      puts "Invalid index."
    end
  else
    puts "No tasks to remove."
  end
end
