#!/usr/bin/ruby

require('rubygems')
gem('twitter4r', '>=0.3.1')
require('twitter')
require 'net/http'
require 'rexml/document';
require 'kconv'

class TwitterBot
  # メイン
  def run
    getfrom = Time.now - 60*10
    timeline=@client.timeline_for(:friends, :count => 200) do |status|
      if getfrom >= status.created_at
        return
      end
      #puts "("+status.created_at.to_s+")"+status.user.screen_name+": "+status.text
      if status.user.screen_name != "mirubot"
        self.extu status
        self.nya status
        self.mention status
      end

      time = Time.now
      if time.hour > 9 && time.hour < 18
        self.workingnow
      end
    end
  end

  def workingnow
    if ARGV.size > 0
      ARGV.each do | user |
        self.countpost user
        if @count > @th
          message = "@" << user << " お仕事してくださいね "
          message = message << "(" << @min.to_s << "分で" << @count.to_s << "ポスト)"
          #puts message
          post message
        end
      end
    end
  end

  def countpost user
    getfrom=Time.now-60*@min
    @count = 0
    timeline=@client.timeline_for(:user, :id => user , :count => 200) do |status|
      if getfrom >= status.created_at
        return
      end
      #puts "("+status.created_at.to_s+")"+status.user.screen_name+": "+status.text
      @count += 1
    end
    return @count
  end

  # えっ
  def extu status
    if status.text =~ /えっ$/
      message = "@"+status.user.screen_name+" えっ？"
      post message
    end
  end
  # にゃん
  def nya status
    if status.text =~ /にゃん$/
      message = "@"+status.user.screen_name+" にゃんにゃんФωФ"
      post message
    end
  end

  # mention reply
  def mention status
    if status.text =~ /^\@mirubot /
      message = "@"+status.user.screen_name+" ヾ（｡＞‿＜｡ ）さみしいの？"
      post message
    end
  end

  def initialize client
    @client = client
    @count = 0
    @min = 30
    @th = 10
  end

  def post message
    @client.status(:post,Kconv.kconv(message,Kconv::UTF8))
    #puts "### "+message
  end

end


# main
client=Twitter::Client.from_config('./mirubot-conf.yaml','bot')
bot=TwitterBot.new client

bot.run

