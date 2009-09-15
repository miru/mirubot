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
require 'logger'

class TwitterBot
  def initialize client
    @client = client
    @count = 0
    @workingmin = 30  # min
    @workingth = 14   # post count
    @timewait = 60*5  # sec
    @idleth = 6       # idle threthold

    @idlecount = 0
    @lastid = 0
    @replylastid = 0
    @replyfirst = true
  end
  
  def run
    @logfile = Logger.new("./log.txt")
    @logfile.level = Logger::INFO
    @logfile.info("Startup mirubot")
    while true
      starttime = Time.now

      # タイムラインチェック
      @logfile.info("Do gettimeline")
      self.gettimeline
      @logfile.info("Do at reply")
      self.atreply

      @idlecount += 1
      if @idlecount >= @idleth
        # 仕事してください
        time = Time.now
        if (time.hour > 9 && time.hour < 12) || (time.hour > 13 && time.hour < 18)
          @logfile.info("Do workingnow")
          self.workingnow
        end
        
        # マルコフ連鎖ポスト
        @logfile.info("Do marcov")
        self.rssmarcov ""
        @idlecount = 0
      end

      difftime = Time.now - starttime
      if difftime < @timewait
        t = @timewait - difftime
        @logfile.info("## sleep " << t.to_s << "sec idle=" << @idlecount.to_s)
        sleep(t)
      end
    end
  end

  # 通常タイムライン取得
  def gettimeline
    oldid = @lastid
    begin
      timeline=@client.timeline_for(:friends, :id => @lastid)
    rescue
      @logfile.warn("Timeline get failed")
    else
      timeline.each do | status |
        if status.id > @lastid
          @lastid = status.id
        end
        if status.id > oldid
          if status.user.screen_name == "mirubot"
            next
          else
            @logfile.info("<<get TL "+status.user.screen_name+": "+status.text+" ID:"+status.id.to_s)
            self.mecabreply status
          end
        end
      end
    end
  end

  # 仕事してください
  def workingnow
    # フレンドリスト取得
    begin
      friends = @client.my(:friends)
    rescue
      @logfile.warn("Friends get faild")
      return
    end

    # フレンドのRSS取得
    for user in friends
      getfrom=Time.now-60*@workingmin
      rss = 'http://twitter.com/status/user_timeline/' << user.screen_name << '.rss'
      sleep(1)
      begin
        userrss = RSS::Parser.parse(rss)
      rescue
        @logfile.warn("workingnow RSS get: " << user.screen_name << " ... fail")
        next
      else
        # ポスト数カウント
        @count = 0
        userrss.items.each do | item |
          if item.date > getfrom
            @count += 1
          end
        end
        if @count > @workingth
          if user.screen_name == "tororosoba"
            message = "@" << user.screen_name << " あのー " << @workingmin.to_s << "分で"\
            << @count.to_s << "ポストしてます。お仕事してください。"
          else
            message = "@" << user.screen_name << " " << @workingmin.to_s << "分で"\
            << @count.to_s << "ポストしてるけどだいじょうぶ？"
          end
          post message
        end
      end
    end
  end

  # めかぶかけて単語に反応
  def mecabreply status
    mecab = MeCab::Tagger.new("-Ochasen")

    a = self.mecabexclude status.text
    node = mecab.parseToNode(a)

    while node
      nodefull = node.surface << " " << node.feature
      @logfile.debug("mecab: "+nodefull)
      if nodefull =~ /ふろ/
        message = "@"+status.user.screen_name+" ほくほく @"+status.user.screen_name+" さん"
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
        message = "@"+status.user.screen_name+" ヾ（＞‿＜｡ ）よしよし"
        post message
      elsif nodefull =~ /ぎゅー/
        message = "@"+status.user.screen_name+" ぎゅっとぎゅっと"
        post message
      elsif nodefull =~ /(さみし|さびし)/
        message = "@"+status.user.screen_name+" わたしはここにいるよ"
        post message
      elsif nodefull =~ /クンカクンカ/
        message = "@"+status.user.screen_name+" くんくん、すんすん"
        post message
      elsif nodefull =~ /(mogmog|gokgok)/
        message = "@"+status.user.screen_name+" おいしそーです (￣￢￣)ジュル"
        post message
      end
      node = node.next
    end
  end

  # ＠が飛んできたら何か返す
  def atreply
    begin
      replyline = @client.timeline_for(:replies)
    rescue
      @logfile.warn("Mentions receive fail")
    else
      replyline.each do |status|
        # 一番最初はリプライしない
        if @replyfirst
          @replylastid = status.id
          @replyfirst = false
          return
        end
        case status.user.screen_name
        when "mirubot", "ha_ma" "wakatter" "ichiyonnana_bot"
          next
        else
          if status.id > @replylastid
            @replylastid = status.id
            @logfile.info("<<get RP "+status.user.screen_name+": "+status.text+" ID:"+status.id.to_s)
            if status.text =~ /(かわい|可愛|かあい|かーいー)/
              message = "@"+status.user.screen_name+" ありがとね (〃▽〃)"
              post message
            elsif status.text =~ /ありがと/
              message = "@"+status.user.screen_name+" どういたしましてっ ＞ω＜"
              post message
            elsif status.text =~ /ぴんぐ/
              message = "@"+status.user.screen_name+" ぽんぐ"
              post message
            else
              self.rssmarcov "@"+status.user.screen_name+" "
            end
          end
        end
      end
    end
  end
  
  def rssmarcov heading
    text = String.new
    text = ""
    
    friends = @client.my(:friends)
    for user in friends
      sleep(1)
      userrss = 'http://twitter.com/status/user_timeline/' << user.screen_name << '.rss'
      begin
        rss = RSS::Parser.parse(userrss)
      rescue
        @logfile.warn("marcov RSS get: " << user.screen_name << " ... fail")
        next
      else
        @logfile.debug("marcov RSS get: " << user.screen_name << " ... success")
      end
      rss.items.each do | item |
        a = self.mecabexclude item.title
        text = text + a
      end
    end

    if text.size == 0
      return
    end

    mecab = MeCab::Tagger.new("-Owakati")
    data = Array.new
    mecab.parse(text + "EOS").split(" ").each_cons(3) do |a|
      data.push h = {'head' => a[0], 'middle' => a[1], 'end' => a[2]}
    end

    maxlen = rand(60) + 40
    d = rand(data.size)
    t1 = data[d]['head']
    t2 = data[d]['middle']
    new_text = heading + t1 + t2

    while true
      break if new_text.size > maxlen
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
    @logfile.info(new_text.gsub(/EOS$/,''))
    post new_text.gsub(/EOS$/,'')
  end

  def mecabexclude str
    a = str.sub(/^.*: /," ")
    a = a.gsub(/\[.*\]/," ")
    a = a.gsub(/\(.*\)/," ")
    a = a.gsub(/\n/," ")
    a = a.gsub(/@[A-Za-z0-9_]+/,"")
    a = a.gsub(/,/,"")
    a = a.gsub(/(https?|ftp)(:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)/,"")
    return a
  end

  def post message
    failflg = true
    while failflg
      begin
        @client.status(:post,Kconv.kconv(message,Kconv::UTF8))
      rescue
        @logfile.warn(">>send fail: "+message)
        sleep(1)
      else
        @logfile.debug(">>send message: "+message)
        failflg = false
      end
    end
  end

end


# main
#WEBrick::Daemon.start {
	client=Twitter::Client.from_config('/home/miru/bin/mirubot-conf.yaml','bot')
	bot=TwitterBot.new client
	bot.run
#}
