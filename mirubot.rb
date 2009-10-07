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

# $KCODE = "UTF-8"

class TwitterBot
  def initialize client
    @client = client
    @count = 0
    @workingmin = 30  # min
    @workingth = 15   # post count
    @timewait = 60*3  # sec
    @idleth = 5       # idle threthold

    @idlecount = 0
    @lastid = 0
    @replylastid = 0
    @replyfirst = true
    @doworkingnowflg = true
    @domarcovflg = true

    @db=SQLite3::Database.new('mirubot.sqlite3')
    @db.type_translation = true

  end
  
  def run
    @logfile = Logger.new("./mirubot.log")
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
        sleep(60)
      else
        failflg = false
        timeline.each do | status |
          if status.id > @lastid
            @lastid = status.id
          end

          sql = "select bot_name from botlist;"

          failflg = true
          bot = Array.new
          while failflg
            begin
              bots = @db.execute(sql)
            rescue
              sleep(5)
            else
              failflg = false
            end
          end

          @logfile.debug("SQL execute: " << sql)
          
          bots.each do | bot |
            if status.user.screen_name == bot[0]
              @logfile.debug("FUNC: gettimeline: bot match")
              next
            end
          end

          @logfile.info("<<get TL "+status.user.screen_name+": "+status.text+" ID:"+status.id.to_s)
          #self.fav status
          self.mecabreply status
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
        sleep(60)
      else
        failflg = false
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
    sql = "select bot_name from botlist;"

    failflg = true
    bots = Array.new
    while failflg
      begin
        bots = @db.execute(sql)
      rescue
        sleep(5)
      else
        failflg = false
      end
    end
    @logfile.debug("SQL execute: " << sql)

    bots.each do | bot |
      if status.user.screen_name == bot[0]
        @logfile.info("FUNC: mecabreply: bot match")
        return
      end
    end

    mecab = MeCab::Tagger.new("-Ochasen")
    a = self.mecabexclude status.text
    node = mecab.parseToNode(a)

    sql = "select id,word from reply_word;"

    failflg = true
    words = Array.new
    while failflg
      begin
        words = @db.execute(sql)
      rescue
        sleep(5)
      else
        failflg = false
      end
    end
    @logfile.debug("FUNC: mecabreply: SQL: " << sql)

    while node
      nodefull = node.surface << " " << node.feature
      @logfile.debug("mecab: "+nodefull)

      words.each do | word |
        if nodefull =~ Regexp.new(word[1])
          sql = "select reply_word from reply_word_list where parent_id = " << word[0].to_s << ";"

          failflg = true
          result = Array.new
          while failflg
            begin
              result = @db.execute(sql)
            rescue
              sleep(5)
            else
              failflg = false
            end
          end

          @logfile.info("FUNC: mecabreply: SQL: " << sql)
          r = rand(result.size)
          message = "@" << status.user.screen_name << " " << result[r][0]
          post message

          break
        end
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
        sleep(60)
      else
        failflg = false
        replyline.each do |status|
          # 一番最初はリプライしない
          if @replyfirst
            @replylastid = status.id
            @replyfirst = false
            return
          end

          sql = "select bot_name from botlist;"
          failflg2 = true
          bot = Array.new
          while failflg2
            begin
              bots = @db.execute(sql)
            rescue
              sleep(5)
            else
              failflg2 = false
            end
          end
          @logfile.debug("SQL execute: " << sql)
          
          bots.each do | bot |
            if status.user.screen_name == bot[0]
              @logfile.info("FUNC: atreply: bot match")
              next
            end
          end

          if status.id > @replylastid
            @replylastid = status.id
            @logfile.info("<<get RP " << status.user.screen_name << ": " << status.text << " ID:" << status.id.to_s)
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
              if @domarcovflg
                flg = false
                while flg == false
                  flg = self.dbmarcov "@" << status.user.screen_name << " "
                end
              end
            end
          end
        end
      end
    end
  end


  def dbmarcov heading
    text = String.new
    text = ""

    maxlen = rand(60) + 40

    # 最初の1語用ランダム生成
    sql = "select * from post_elem;"
    failflg = true
    result = Array.new
    while failflg
      begin
        result = @db.execute(sql)
      rescue
        sleep(5)
      else
        failflg = false
      end
    end
    d = rand(result.size)

    t1 = result[d][2]
    t2 = result[d][3]
    new_text = heading << t1 << t2
    
    # 続きを生成
    while true
      # 最大文字以上になったらループを抜ける
      break if new_text.size > maxlen

      # 要素1要素2と同じものをSELECTする
      sql = "select * from post_elem where elem1='" << t1 << "' and elem2='" << t2 << "';"
      failflg = true
      result = Array.new
      while failflg
        begin
          result = @db.execute(sql)
        rescue
          sleep(5)
        else
          failflg = false
        end
      end

      # なかったらループを抜ける
      break if result.size == 0

      # ランダムで選択
      d = rand(result.size)

      # 選択したものをくっつける
      new_text = new_text + result[d][4]
      break if result[d][4] == "EOS"
      t1 = result[d][3]
      t2 = result[d][4]
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
        @logfile.warn(">>send fail: " << message)
        sleep(30)
      else
        @logfile.info(">>send message: " << message)
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
