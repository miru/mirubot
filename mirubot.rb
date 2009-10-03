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
require 'sqlite3'

class TwitterBot
  def initialize client
    @client = client
    @count = 0
    @workingmin = 30  # min
    @workingth = 16   # post count
    @timewait = 60*3  # sec
    @idleth = 10      # idle threthold

    @idlecount = 0
    @lastid = 0
    @replylastid = 0
    @replyfirst = true
    @doworkingnowflg = true
    @domarcovflg = true
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
        if @doworkingnowflg
          time = Time.now
          if (time.hour > 9 && time.hour < 12) || (time.hour > 13 && time.hour < 18)
            @logfile.info("Do workingnow")
            self.workingnow
          end
        end
        
        # マルコフ連鎖ポスト
        if @domarcovflg
          @logfile.info("Do marcov")
          flg = false
          while flg == false
            #flg = self.rssmarcov ""
            flg = self.dbmarcov ""
          end
          @idlecount = 0
        end
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
    failflg = true
    while failflg
      begin
        timeline=@client.timeline_for(:friends, :id => @lastid)
      rescue
        @logfile.warn("Timeline get failed")
        sleep(30)
      else
        failflg = false
        timeline.each do | status |
          if status.id > @lastid
            @lastid = status.id
          end
          if status.id > oldid
            if status.user.screen_name == "mirubot" 
              next
            elsif status.user.screen_name == "ha_ru_ka"
              next
            elsif status.user.screen_name == "ichiyonnana_bot"
              next
            else
              @logfile.info("<<get TL "+status.user.screen_name+": "+status.text+" ID:"+status.id.to_s)
              #self.fav status
              self.mecabreply status
            end
          end
        end
      end
    end
  end

  # 仕事してください
  def workingnow
    # フレンドリスト取得
    failflg = true
    while failflg
      begin
        friends = @client.my(:friends)
      rescue
        @logfile.warn("Friends get faild")
        sleep(30)
      else
        failflg = false
      end
    end

    # フレンドのRSS取得
    for user in friends
      if uesr.screen_name == "ha_ru_ka"
        next
      elsif user.screen_name == "ichiyonnana_bot"
        next
      end

      getfrom=Time.now-60*@workingmin
      rss = 'http://twitter.com/status/user_timeline/' << user.id.to_s << '.rss'
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

  # ふぁぼるよー
  def fav status
    begin
      if status.text =~ /(みるぼっと)/
        @client.favorite(:add, status)
      elsif status.text =~ /(ねこ|ネコ|にゃー|ニャー)/
        @client.favorite(:add, status)
      elsif status.text =~ /＞ω＜/
        @client.favorite(:add, status)
      elsif status.text =~ /暴走/
        @client.favorite(:add, status)
      elsif status.text =~ /(みるたん|みるぽん|みるさん)/
        @client.favorite(:add, status)
      elsif status.text =~ /なでなで/
        @client.favorite(:add, status)
      elsif status.text =~ /ありがと/
        @client.favorite(:add, status)
      end
    rescue
        @logfile.warn("Add favorite error")
    end      
  end

  # めかぶかけて単語に反応
  def mecabreply status
    mecab = MeCab::Tagger.new("-Ochasen")

    if status.user.screen_name == "mirubot"
      return
    elsif status.user.screen_name == "ha_ma"
      return
    elsif status.user.screen_name == "wakatter"
      return
    elsif status.user.screen_name == "ichiyonnana_bot"
      return
    elsif status.user.screen_name == "ha_ru_ka"
      return
    end

    a = self.mecabexclude status.text
    node = mecab.parseToNode(a)

    while node
      nodefull = node.surface << " " << node.feature
      @logfile.debug("mecab: "+nodefull)
      if nodefull =~  /(はーい)/
        message = "@"+status.user.screen_name+" ヾ（＞ω＜｡ ）いいこいいこ"
        post message
      elsif nodefull =~ /もふもふ/
        message = "@"+status.user.screen_name+" もっふもふにしてやんよーっ！＞ω＜"
        post message
      elsif nodefull =~ /ちゅっちゅ/
        message = "@"+status.user.screen_name+" さんがちゅっちゅ （＞ε＜）"
        post message
      elsif nodefull =~ /なでなで/
        message = "@"+status.user.screen_name+" ヾ（＞ω＜  ）よしよし"
        post message
      elsif nodefull =~ /ぎゅー/
        message = "@"+status.user.screen_name+" ぎゅっとぎゅっと"
        post message
      end
      node = node.next
    end
  end

  # ＠が飛んできたら何か返す
  def atreply
    failflg = true
    while failflg
      begin
        replyline = @client.timeline_for(:replies)
      rescue
        @logfile.warn("Mentions receive fail")
        sleep(30)
      else
        failflg = false
        replyline.each do |status|
          # 一番最初はリプライしない
          if @replyfirst
            @replylastid = status.id
            @replyfirst = false
            return
          end
          if status.user.screen_name == "mirubot"
            next
          elsif status.user.screen_name == "ha_ma"
            next
          elsif status.user.screen_name == "wakatter"
            next
          elsif status.user.screen_name == "ichiyonnana_bot"
            next
          elsif status.user.screen_name == "ha_ru_ka"
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
              elsif status.text =~ /(状態|じょうたい)/
                if (status.user.screen_name == "miru") || (status.user.screen_name == "mirupon")
                  @domarcovflg = true
                  message = "@"+status.user.screen_name+" マルコフ連鎖:"
                  if @domarcovflg
                    message = message+"ON"
                  else
                    message = message+"OFF"
                  end
                  message = message+" ポスト数カウント: "
                  if @doworkingnowflg
                    message = message+"ON"
                  else
                    message = message+"OFF"
                  end
                  post message
                end
              elsif status.text =~ /(マルコフ|まるこふ)(開始|かいし)/
                if (status.user.screen_name == "miru") || (status.user.screen_name == "mirupon")
                  @domarcovflg = true
                  message = "@"+status.user.screen_name+" マルコフ連鎖機能開始します。"
                  post message
                end
              elsif status.text =~ /(マルコフ|まるこふ)(停止|ていし)/
                if (status.user.screen_name == "miru") || (status.user.screen_name == "mirupon")
                  @domarcovflg = false
                  message ="@"+status.user.screen_name+" マルコフ連鎖機能停止します。"
                  post message
                end
              elsif status.text =~ /(カウント|かうんと)(開始|かいし)/
                if (status.user.screen_name == "miru") || (status.user.screen_name == "mirupon")
                  @doworkingnowflg = true
                  message ="@"+status.user.screen_name+" カウント機能開始します。"
                  post message
                end
              elsif status.text =~ /(カウント|カウント)(停止|ていし)/
                if (status.user.screen_name == "miru") || (status.user.screen_name == "mirupon")
                  @doworkingnowflg = false
                  message = "@"+status.user.screen_name+" カウント機能停止します。"
                  post message
                end
              else
                if @domarcovflg
                  flg = false
                  while flg == false
                    #flg = self.rssmarcov "@"+status.user.screen_name+" "
                    flg = self.dbmarcov "@"+status.user.screen_name+" "
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  
  def rssmarcov heading
    text = String.new
    text = ""
    begin
      friends = @client.my(:friends)
    rescue
      return
    end

    for user in friends
      userrss = 'http://twitter.com/status/user_timeline/' << user.screen_name << '.rss'
      begin
        rss = RSS::Parser.parse(userrss)
      rescue
        @logfile.warn("marcov RSS get: " << user.screen_name << " ... fail")
        next
      else
        @logfile.info("marcov RSS get: " << user.screen_name << " ... success")
      end
      rss.items.each do | item |
        a = self.mecabexclude item.title
        text = text + a
      end
    end

    if text.size == 0
      @logfile.warn("marcov RSS get: all fail")
      sleep(10)
      return false
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
    post new_text.gsub(/EOS$/,'')
    return true
  end

  def dbmarcov heading
    text = String.new
    text = ""

    db=SQLite3::Database.new('mirupost.sqlite3')
    db.type_translation = true

    sql = "select status_text from posts;"
    result = db.execute(sql)
    result.each do | post |
      text = text << " " << post[0]
    end

    if text.size == 0
      p "marcov DB timeline get: all fail"
      return false
    end

    text = self.mecabexclude text

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
    post new_text.gsub(/EOS$/,'')
    return true
  end

  def mecabexclude str
    a = str.sub(/^.*: /," ")
    a = a.gsub(/(https?|ftp)(:\/\/[-_\.\!\~\*\'\(\)a-zA-Z0-9;\/?:\@\&=+\$,\%\#]+)/," ")
    a = a.gsub(/[＞＜⌒＞＜←→]/," ")
    a = a.gsub(/【.*】/," ")
    a = a.gsub(/（.*）/," ")
    a = a.gsub(/[「」]/," ")
    a = a.gsub(/\[.*\]/," ")
    a = a.gsub(/\(.*\)/," ")
    a = a.gsub(/\n/," ")
    a = a.gsub(/@[A-Za-z0-9_]+/," ")
    #a = a.gsub(/[A-Za-z]+/," ")
    a = a.gsub(/[:\.,\/_\*\"]+/,"")
    return a
  end

  def post message
    failflg = true
    while failflg
      begin
        @client.status(:post,Kconv.kconv(message,Kconv::UTF8))
      rescue
        @logfile.warn(">>send fail: "+message)
        sleep(10)
      else
        @logfile.info(">>send message: "+message)
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
