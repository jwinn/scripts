#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/lib-trollop.rb'
require 'find'

# parse options

opts = Trollop::options do
    version 'rename.rb 0.0.1 (C) 2012 Jon Winn'
    banner <<-EOS
Uses regular expressions to change file/folder names

Usage:
    rename [options] [<working_directory>]

working_directory uses the present working directory of the process,
    not where the script is located, if not specified

where [options] are:
EOS

    opt :recursive, 'Recursive rename', :short => '-r', :default => true
    opt :prefix, 'Prefix to leave untouched', :short => '-p', :type => String
    opt :prefix_ignore_case, 'Ignore case of prefix', :default => false
    opt :match, 'Regex to match string', :short => '-m', :default => '\.', :type => String
    opt :substitution, 'Regex to replace matched string with', :short => '-s', :default => ' ', :type => String
    opt :test, 'Test to see what the processing would be', :short => '-t', :default => false
end

script_dir = File.dirname(__FILE__)
wd = Dir.pwd

unless ARGV.empty?
    wd = ARGV.pop
end

cmds = []
Find.find(wd) do |path|
    file = File.basename(path)
    dir = File.dirname(path)

    if File.directory?(path)
        file.gsub!(/#{opts[:match]}/, opts[:substitution])

        new_path = File.join(dir, file)
        cmds << "mv \"#{path}\" \"#{new_path}\""
    end
end

cmds.each do |cmd|
    puts cmd
end
