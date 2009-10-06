#!/usr/bin/ruby

require('rubygems')
gem('twitter4r', '>=0.3.1')
require('twitter')
require 'net/http'
require 'rexml/document';
require 'kconv'


# set twitter account
account = {
  'login' =>'mirubot',
  'password' =>'XXXXXXXX',
}


# make twitter client
client = Twitter::Client.new( :login => account['login'], :password => account['password'] )

if ARGV.size > 0 then
  ARGV.each do | argstr |
    failflg = true
    while failflg
      begin
        client.status(:post, argstr)
      rescue
        sleep(5)
      else
        failflg = false
      end
    end
  end
end



