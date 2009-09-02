#!/usr/bin/ruby

require('rubygems')
gem('twitter4r', '>=0.3.1')
require('twitter')
require 'net/http'
require 'rexml/document';
require 'kconv'
require 'rss' 
require 'webrick'
require "MeCab"



class TwitterBot
  def initialize client
    @client = client
    @count = 0
    @workingmin = 30
    @workingth = 14
    @timewait = 60*5
    @idlecount = 0
    @idleth = 6
    @postflg = false
  end
  
  def run
    while true
      getfrom = Time.now - @timewait + 3
      timeline=@client.timeline_for(:friends, :since => getfrom) do |status|
        if status.created_at <= getfrom
          next
        end
        
        puts "<<get TL("+status.created_at.strftime("%H:%M:%S")+") "+status.user.screen_name+": "+status.text+" ID:"+status.id.to_s
        
        if status.user.screen_name != "mirubot"
          self.autoreply status
          sleep(1)
        end
        
        time = Time.now
        if (time.hour > 9 && time.hour < 12) || (time.hour > 13 && time.hour < 17)
          puts "## workingnow"
          self.workingnow
        end
      end

      if @postflg == true
        @idlecount = 0
      else
        @idlecount += 1
      end
      if @idlecount >= @idleth
        message = "私はあいどる！※生存確認的な意味で"
        post message
        @idlecount = 0
      end

      puts "## sleep " << Time.now.strftime("%H:%M:%S") << " " << @timewait.to_s << "sec idle=" << @idlecount.to_s
      @postflg = false
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
  
  def autoreply status
    puts "== " << status.text
    
    if status.text =~ /^@mirubot /
      atreply status
    else
      mecabreply status
    end
  end

  def mecabreply status
    mecab = MeCab::Tagger.new("-Ochasen")
    node = mecab.parseToNode(status.text)
    while node
      nodefull = node.surface << " " << node.feature
      puts "== " << nodefull
      if nodefull =~ /^えっ /
        message = "@"+status.user.screen_name+" なにそれこわい"
        post message
      elsif nodefull =~ /にゃん /
        message = "@"+status.user.screen_name+" にゃんにゃんФωФ"
        post message
      elsif nodefull =~ /本気/
        message = "@"+status.user.screen_name+" 本気ですか！頑張ってくださいね ｡＞‿＜｡"
        post message
      elsif nodefull =~ /ぱっつん/
        message = "@"+status.user.screen_name+" ぱっつんと聞いて！"
        post message
      elsif nodefull =~ /(ベッド|フトン)/
        message = "@"+status.user.screen_name+" おふとんもふもふー＞ω＜！"
        post message
      elsif nodefull =~ /もふもふ/
        message = "@"+status.user.screen_name+" もっふもふにしてやんよーっ！"
        post message
      elsif nodefull =~ /ぺろぺろ/
        message = "@"+status.user.screen_name+" ぺろぺろしすぎに注意しましょうね"
        post message
      elsif nodefull =~ /(mogmog|gokgok)/
        message = "@"+status.user.screen_name+" おいしそーです (￣￢￣)ジュル"
        post message
      end
      node = node.next
    end
  end
  
  def atreply status
    if status.text =~ /(かわい|可愛)/
      message = "@"+status.user.screen_name+" ありがとね (〃▽〃)"
      post message
    elsif status.text =~ / ありがと/
      message = "@"+status.user.screen_name+" どういたしましてっ ＞ω＜"
      post message
    elsif status.text =~ / ぴんぐ/
      message = "@"+status.user.screen_name+" ぽんぐ"
      post message
    end
  end
  
  def post message
    @client.status(:post,Kconv.kconv(message,Kconv::UTF8))
    @postflg = true
    puts ">>send message: "+message
  end
end


# main
#WEBrick::Daemon.start {
	client=Twitter::Client.from_config('/home/miru/bin/mirubot-conf.yaml','bot')
	bot=TwitterBot.new client

	bot.run
#}
