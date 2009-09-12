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
    @idleth = 3
    @postflg = false
    @lastid = 0
  end
  
  def run
    while true

      # get timeline
      getfrom = Time.now - @timewait + 3
      begin
        timeline=@client.timeline_for(:friends, :id => @lastid)
      rescue
        puts "Timeline get failed"
      else
        timeline.each do |status|
          if status.created_at <= getfrom
            next
          end
          if status.id > @lastid
            @lastid = status.id
          end
          
          puts "<<get TL("+status.created_at.strftime("%H:%M:%S")+") "+status.user.screen_name+": "+status.text+" ID:"+status.id.to_s
          
          if status.user.screen_name != "mirubot"
            self.autoreply status
            sleep(1)
          end
        end
      end

      # workingnow
      time = Time.now
      if (time.hour > 9 && time.hour < 12) || (time.hour > 13 && time.hour < 18)
        puts "Do workingnow"
        self.workingnow
      end
    
      if @postflg == true
        @idlecount = 0
      else
        @idlecount += 1
      end
      if @idlecount >= @idleth
        self.rssmarcov
        @idlecount = 0
      end

      puts "## sleep " << Time.now.strftime("%H:%M:%S") << " " << @timewait.to_s << "sec idle=" << @idlecount.to_s
      @postflg = false
      sleep(@timewait)
    end
  end
  
  def workingnow
    begin
      friends = @client.my(:friends)
    rescue
      puts "Friends get faild"
      return
    end

    for user in friends
      begin
        sleep(1)
        getfrom=Time.now-60*@workingmin
        rss = 'http://twitter.com/status/user_timeline/' << user.screen_name << '.rss'
        userrss.push RSS::Parser.parse(rss)
      rescue
        puts "workingnow RSS get: " << user.screen_name << " ... fail"
        next
      else
        #puts "workingnow RSS get: " << user.screen_name << " ... success"
        @count = 0
        rss.items.each do | item |
          if item.date > getfrom
            @count += 1
          end
        end
        if @count > @workingth
          message = "@" << user.screen_name << " おっしっごっとしまっしょ！(▰╹◡╹▰) "
          message = message << "(" << @workingmin.to_s << "分で" << @count.to_s << "ポスト)"
          post message
        end
      end
    end
  end
  
  def autoreply status
    #puts "== " << status.text
    
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
      #puts "== " << nodefull
      if nodefull =~ /^えっ /
        message = "@"+status.user.screen_name+" なにそれこわい （ﾟдﾟlll）"
        post message
      elsif nodefull =~ /にゃん /
        message = "@"+status.user.screen_name+" にゃかにゃかにゃんФωФ"
        post message
      elsif nodefull =~ /(ベッド|フトン)/
        message = "@"+status.user.screen_name+" おふとんもふもふー＞ω＜！"
        post message
      elsif nodefull =~ /もふもふ/
        message = "@"+status.user.screen_name+" もっふもふにしてやんよーっ！ ＞ω＜"
        post message
      elsif nodefull =~ /ぺろぺろ/
        message = "@"+status.user.screen_name+" ぺろぺろしすぎに注意しましょうね"
        post message
      elsif nodefull =~ /なでなで/
        message = "@"+status.user.screen_name+" ヾ（｡＞‿＜｡ ）よしよし"
        post message
      elsif nodefull =~ /ぎゅー/
        message = "@"+status.user.screen_name+" ぎゅっとぎゅっと"
        post message
      elsif nodefull =~ /さみしい/
        message = "@"+status.user.screen_name+" わたしはここにいるよ"
        post message
      elsif nodefull =~ /(mogmog|gokgok)/
        message = "@"+status.user.screen_name+" おいしそーです (￣￢￣)ジュル"
        post message
      end
      node = node.next
    end
  end
  
  def atreply status
    if status.text =~ /(かわい|可愛|かあい|かーいー)/
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
  
  def rssmarcov
    text = String.new
    text = ""
    
    friends = @client.my(:friends)
    for user in friends
      
      begin
        sleep(1)
        userrss = 'http://twitter.com/status/user_timeline/' << user.screen_name << '.rss'
        rss = RSS::Parser.parse(userrss)
      rescue
        puts "marcov RSS get: " << user.screen_name << " ... fail"
        next
      else
        #puts "marcov RSS get: " << user.screen_name << " ... success"
      end
      rss.items.each do | item |
        text = text + item.title.sub(/^.*: /," ")
      end
    end

    if text == ""
      return
    end
    text = text.gsub(/@[A-Za-z0-9]+/,"")
    text = text.gsub(/(https?|ftp)(:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)/,"")

    mecab = MeCab::Tagger.new("-Owakati")
    data = Array.new
    mecab.parse(text + "EOS").split(" ").each_cons(3) do |a|
      data.push h = {'head' => a[0], 'middle' => a[1], 'end' => a[2]}
    end

    t1 = data[0]['head']
    t2 = data[0]['middle']
    new_text = t1 + t2
    while true
      break if new_text.size > 70
      _a = Array.new
      data.each do |hash|
        _a.push hash if hash['head'] == t1 && hash['middle'] == t2
      end
      break if _a.size == 0
      num = rand(_a.size)
      new_text = new_text + _a[num]['end']
      break if _a[num]['end'] == "EOS"
      t1 = _a[num]['middle']
      t2 = _a[num]['end']
    end
    puts new_text.gsub(/EOS$/,'')
    post new_text.gsub(/EOS$/,'')
  end

  def post message
    @client.status(:post,Kconv.kconv(message,Kconv::UTF8))
    @postflg = true
    puts ">>send message: "+message
  end

end


# main
WEBrick::Daemon.start {
	client=Twitter::Client.from_config('/home/miru/bin/mirubot-conf.yaml','bot')
	bot=TwitterBot.new client

	bot.run
}
