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
    @workingth = 20   # post count
    @timewait = 60*3  # sec
    @idleth = 10      # idle threthold

    @idlecount = 0
    @botcount = 0
    @lastid = 0

    @lastdt = Time.new
    @lastrepdt = Time.new

    @doworkingnowflg = true
    @domarcovflg = true
    @marcovtoggle = true

    @db=SQLite3::Database.new('mirubot.sqlite3')
    @db.type_translation = true

  end
  
  def run
    @logfile = Logger.new("./mirubot.log")
    @logfile.level = Logger::INFO
    @logfile.info("Startup mirubot")

    sql = "select count() from posts;"
    post_cnt = @db.execute(sql)
    sql = "select count() from post_elem;"
    elem_cnt = @db.execute(sql)

    message = "現在の保存ポスト数: " << post_cnt[0][0].to_s << "  形態素解析数: " << elem_cnt[0][0].to_s
    post message

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
        #if @doworkingnowflg
        #  time = Time.now
        #  if (time.hour > 9 && time.hour < 12) || (time.hour > 13 && time.hour < 18)
        #    @logfile.info("Do workingnow")
        #    self.workingnow
        #  end
        #end
        
        # マルコフ連鎖ポスト
        if @domarcovflg
          @logfile.info("Do marcov")
          if @marcovtoggle
            self.dbmarcov ""
            @marcovtoggle = false
          else
            self.dbmarcov2 ""
            @marcovtoggle = true
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
    failflg = true
    while failflg
      begin
        timeline=@client.timeline_for(:friends, :id => @lastid)
      rescue
        @logfile.warn("Timeline get failed")
        sleep(60)
      else
        failflg = false
      end
    end

    timeline.each do | status |
      if self.botchk status.user.screen_name
        next
      end
      
      @logfile.info("<<get TL " << status.user.screen_name << ": " << status.text+" ID:" << status.id.to_s)
      #self.fav status
      self.mecabreply status
    end

    @lastdt = Time.now
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
          if self.botchk user.screen_name
            next
          end
          
          getfrom=Time.now-60*@workingmin
          rss = 'http://twitter.com/status/user_timeline/' << user.id.to_s << '.rss'
          failflg2 = true
          count = 0
          while failflg2
            count += 1
            begin
              userrss = RSS::Parser.parse(rss)
            rescue
              @logfile.warn("workingnow RSS get: " << user.screen_name << " ... fail")
              sleep(1)
              next
            else
              failflg2 = false
            end
            if count>5
              next
            end
          end

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

    mecab = MeCab::Tagger.new("-Ochasen")
    a = self.mecabexclude status.text
    node = mecab.parseToNode(a)

    failflg = true
    words = Array.new
    sql = "select id,word from reply_word;"
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
      end
    end

    # DBから反応単語を抜き出しておく
    sql = "select * from sence_word;"
    sencelist = @db.execute(sql)
    
    replyline.each do | status |
      # 古い発言は反応しない
      if status.created_at < @lastrepdt
        next
      end

      # botチェック
      if self.botchk status.user.screen_name
        if @botcount > 3
          next
        end
      end

      if @botcount > 10
        @botcount = 0
      end

      @logfile.info("<<get RP " << status.user.screen_name << ": " << status.text << " ID:" << status.id.to_s)

      senceflg = false
      sencelist.each do | word |
        if status.text =~ Regexp.new(word[1])
          sql = "select sence_word_list from sence_word_list where parent_id=" << word[0].to_s << ";"
          rep = @db.execute(sql)
          d = rand(rep.size)
          message = "@" << status.user.screen_name << rep[d][0]
          post message
          senceflg = true
          break
        end
      end
      if @domarcovflg
        if senceflg == false
          if @marcovtoggle 
            self.dbmarcov "@" << status.user.screen_name << " "
            @marcovtoggle = false
          else
            self.dbmarcov2 "@" << status.user.screen_name << " "
            @marcovgoggle = true
          end
        end
      end
    end
    @lastrepdt = Time.now
  end


  # マルコフ連鎖 3要素版
  def dbmarcov heading
    text = String.new

    maxlen = rand(100) + 40

    # 最初の1語用ランダム生成
    sql = "select * from post_elem where word_index=1;"
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
  

  # マルコフ連鎖 2要素版
  def dbmarcov2 heading
    text = String.new
    text = ""

    maxlen = rand(100) + 40

    # 最初の1語用ランダム生成
    sql = "select * from post_elem where word_index=1;"
    result = @db.execute(sql)
    datasize = result.size

    d = rand(datasize)

    t1 = result[d][2]
    new_text = heading + t1

    # 続きを生成
    while true
      # 最大も自重になったらループを抜ける
      break if new_text.size > maxlen


      # 要素1要素2と同じものをSELECTする
      sql = "select * from post_elem where elem1='" << t1 << "';"
      result = @db.execute(sql)
      break if result.size == 0

      d = rand(result.size)

      # 選択したものをくっつける
      new_text = new_text + result[d][3]
      #break if result[d][4] == "EOS"
      t1 = result[d][3]
    end
    post new_text.gsub(/EOS$/,'')
    return true
  end

  # めかぶかける前に特定文字列を削除
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
    a = a.gsub(/[:\.,\/_\*\"]+/," ")
    return a
  end


  # bot判定
  def botchk user
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

    bots.each do | bot |
      if user == bot[0]
        @logfile.debug("FUNC: bot match:" << bot[0])
        return true
      end
    end
    return false
  end

  # ポスト
  def post message
    failflg = true
    while failflg
      begin
        @client.status(:post,Kconv.kconv(message << " …ですの",Kconv::UTF8))
        #p message
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
