#!/usr/bin/ruby

require('rubygems')
gem('twitter4r', '>=0.3.1')
require('twitter')
require 'net/http'
require 'rexml/document';
require 'kconv'
require 'rss' 

class TwitterBot
	def initialize client
		@client = client
		@count = 0
		@workingmin = 30
		@workingth = 10
		@timewait = 60*5
		@autoreplyflg = false
		@finflg = true
	end

	def run
		while @finflg
			getfrom = Time.now - @timewait + 3
			timeline=@client.timeline_for(:friends, :count => 200) do |status|
				if status.created_at <= getfrom
					next
				end

				puts "<<get TL("+status.created_at.strftime("%H:%M:%S")+") "+status.user.screen_name+": "+status.text

				if status.user.screen_name != "mirubot"
					self.autoreply status
				end

				time = Time.now
				if (time.hour > 9 && time.hour < 12) || (time.hour > 13 && time.hour < 17)
					self.workingnow
				end
			end
			sleep(@timewait)
		end
	end

	def workingnow
		friends = @client.my(:friends)
		for user in friends
			self.countpost user.screen_name
			if @count > @workingth
				message = "@" << user.screen_name << " お仕事してくださいね "
				message = message << "(" << @workingmin.to_s << "分で" << @count.to_s << "ポスト)"
				post message
			end
		end
	end

	def countpost user
		getfrom=Time.now-60*@workingmin
		@count = 0
		userrss = 'http://twitter.com/status/user_timeline/' << user << '.rss'
		rss = RSS::Parser.parse(userrss)
		rss.items.each do | item |
			if item.date > getfrom
				@count += 1
			end
		end
		return @count
	end

	# えっ
	def autoreply status
		if @autoreplyflg == false
			if status.text =~ /^@mirubot (えっ|えっ？)$/
				message = "@"+status.user.screen_name+" なにそれこわい"
				post message
				@autoreplyflg = true
			elsif status.text =~ /(えっ|えっ？)$/
				message = "@"+status.user.screen_name+" えっ？"
				post message
				@autoreplyflg = true
			elsif status.text =~ /にゃん$/
				message = "@"+status.user.screen_name+" にゃんにゃんФωФ"
				post message
				@autoreplyflg = true
			elsif status.text =~ /本気/
				message = "@"+status.user.screen_name+" 本気ですか！頑張ってくださいね ｡＞‿＜｡"
				post message
				@autoreplyflg = true
			elsif status.text =~ /ぱっつん/
				message = "@"+status.user.screen_name+" ぱっつんと聞いて！"
				post message
				@autoreplyflg = true
			elsif status.text =~ /(mogmog|gokgok)/
				message = "@"+status.user.screen_name+" おいしそーです (￣￢￣)ジュル"
				post message
				@autoreplyflg = true
			elsif status.text =~ /^@mirubot .*ありがと/
				message = "@"+status.user.screen_name+" どういたしましてなのよ ＞ω＜"
				@autoreplyflg = true
			elsif status.text =~ /^@mirubot .*(かわい|可愛)/
				message = "@"+status.user.screen_name+" ありがとね (〃▽〃)"
				post message
				@autoreplyflg = true
			elsif status.text =~ /^@mirubot /
				message = "@"+status.user.screen_name+" ヾ（｡＞‿＜｡ ）さみしいの？"
				post message
				@autoreplyflg = true
			end
			
		end
	end

	def post message
		@client.status(:post,Kconv.kconv(message,Kconv::UTF8))
		puts ">>send message: "+message
	end
end


# main
client=Twitter::Client.from_config('/home/miru/bin/mirubot-conf.yaml','bot')
bot=TwitterBot.new client

bot.run

