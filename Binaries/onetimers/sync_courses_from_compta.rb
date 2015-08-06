#!/usr/bin/env ruby
%w( QooxView AfriCompta LibNet Network/lib Hilink/lib HelperClasses/lib Gestion ).each { |l|
  $LOAD_PATH.push "../../../#{l}"
}
$LOAD_PATH.push "."

=begin
Due to a problem in the CSV-save module, most of the CSV-data hasn't been saved!!
This was mostly a problem for the sign-ups of the students that were missing
in the courses.
=end

DEBUG_LVL=1
$config_file='config.yaml'

require 'QooxView'
require 'ACQooxView'
require 'LibNet'
require 'Label'
ACQooxView.load_entities

unless File.exists? 'data/'
  dputs(0) { "Didn't find data/-directory, aborting" }
  exit -1
end

QooxView.init('../../Entities', '../../Views')

course_accounts = []

CourseTypes.search_all().each { |ct|
  if ct.account_base
    ct.account_base.accounts.each { |a|
      course_accounts.push a
    }
  end
}

course_accounts.uniq!

Courses.search_all().each { |c|
  if ca = c.entries
    if course_accounts.index ca
      course_accounts.delete ca
      puts "Linked: #{c.name}"
      puts "Students    before: #{c.students.sort.to_s}"
      std = ca.movements.select { |m| m.desc =~ /^For student/ }.map{|m|
      m.desc.match( /.* ([^ :]*):.*/ )[1]}.uniq
      puts "Students in compta: #{std.sort.to_s}"
      c.students = ( c.students + std ).sort.uniq
      puts "Merged            : #{c.students.sort.to_s}"
    else
      puts "Not linked: #{c.name}"
    end
  elsif c.name =~ /_14/
    puts "Missing link: #{c.name}"
  end
}

Entities.save_all

begin
course_accounts.each { |ca|
  if ca.path =~ /14/ and ca.movements.length > 0
    puts "Not linked: #{ca.path}"
    if c = Courses.match_by_name( ca.name )
      puts "Late finding: #{ca.path} - #{c.name}"
    end
    ca.movements.each{|m|
      puts m.to_json
    }
  end
}
end