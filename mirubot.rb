#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
gem('twitter4r', '>=0.3.1')
require 'twitter'
require 'net/http'
require 'rexml/document'
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

    @timewait = 90         # sec
    @autoposttime = 60*20  # sec
    @workingmin = 30       # min
    @workingth  = 15       # post count

    @domarcovflg = true
    @lastmarcovdt = Time.now()

    @db=SQLite3::Database.new('mirubot.sqlite3')
    @db.type_translation = true

    sql = "select last from lastpost where name = 'normal';"
    begin
      result = @db.execute(sql)
    rescue
      sleep(5)
      retry
    end
    @normalid = result[0][0].to_i
  end
  
  
  def run
    @log = Logger.new("./mirubot.log")
    @log.level = Logger::INFO
    @log.info("Startup mirubot")
     
    doneuser = Array.new

    sql = "select count() from post_elem;"
    elem_cnt = @db.execute(sql)
    message = "現在の形態素解析数: " + elem_cnt[0][0].to_s + " "
    #post message

    
    # メインループ
    while true
      starttime = Time.now
      
      # タイムラインチェック
      @log.info("Check timeline from DB")
      posts = Array.new()
      sql = "select user,status_text,rowid from posts where rowid > " + @normalid.to_s + " order by dt;"
      @log.debug("SQL: " + sql)
      failflg = true
      while failflg
        begin
          posts = @db.execute(sql)
        rescue
          sleep(5)
        else
          failflg = false
        end
      end
      
      doneuser.clear
      posts.each do | po |
        @log.debug("TL: " + po[0] + ": " + po[1])

        # 自分は除外
        if po[0] =~ /mirubot/
          next
        end

        # botは1/3の確率で反応する
        if self.botchk po[0]
          if rand(2) == 0
            next
          end
        end
        
        # 1回の取得で1ユーザーあたり1回のみ反応
        doneflg = false
        doneuser.each do | u |
          if u == po[0]
            doneflg = true
            break
          end
        end
        if doneflg
          @log.info("SKIP: Already replied: " + po[0])
          next
        end
        
        # リプライチェック
        if po[1] =~ /(@mirubot)/
          self.dbmarcov "@" + po[0] + " "
          doneuser.push po[0]
        else
          # めかぶキーワードチェック
          if self.mecabreply(po[0], po[1])
            doneuser.push po[0]
          end
        end

        # 最大ROWIDを保存
        if @normalid < po[2].to_i
          @normalid = po[2].to_i
        end
      end
    
      # 最終チェックあぷでと
      sql = "update lastpost set last = " + @normalid.to_s + " where name = 'normal';"
      @log.debug("SQL: " + sql)
      begin
        @db.execute(sql)
      rescue
        sleep(5)
        retry
      end
      @log.info("@normalid:" + @normalid.to_s)
    
    
      # XX分に1度発動
      if (@lastmarcovdt.to_i + @autoposttime) < Time.now().to_i        
        # マルコフ連鎖ポスト
        if @domarcovflg
          @log.info("Do marcov")
          self.dbmarcov ""
        end
        @lastmarcovdt = Time.now()
      end
      
      difftime = Time.now - starttime
      if difftime < @timewait
        t = @timewait - difftime
        @log.info("## sleep " + t.to_s + "sec")
        sleep(t)
      end
    end
  end
  
  
  # めかぶかけて単語に反応
  def mecabreply(user,statustext)
    mecab = MeCab::Tagger.new("-Ochasen")
    a = self.mecabexclude statustext
    node = mecab.parseToNode(a)
    doflg = false
    
    words = Array.new
    sql = "select id,word from reply_word;"
    begin
      words = @db.execute(sql)
    rescue
      sleep(5)
      retry
    end
    @log.debug("SQL: " + sql)
    
    while node
      nodefull = node.surface + " " + node.feature
      @log.debug("mecab: "+nodefull)
      
      words.each do | word |
        if nodefull =~ Regexp.new(word[1])
          sql = "select reply_word from reply_word_list where parent_id = " + word[0].to_s + ";"
          
          result = Array.new
          begin
            result = @db.execute(sql)
          rescue
            sleep(5)
            retry
          end
          
          @log.info("SQL: " + sql)
          r = rand(result.size)
          message = "@" + user + " " + result[r][0]
          post message
          doflg = true
          break
        end
      end
      
      node = node.next
    end
    return doflg
  end

  def workingnow
    countfrom = Time.now().to_i - 60*@workingmin
    @workingth  = 20   # post count
    
    sql = "select user,count(*) from posts where dt > " + countfrom.to_s + " group by user;"
    begin
      result = @db.execute(sql)
    rescue
      sleep(5)
      retry
    end

    result.each do | po |
      if po[0] > @workingth
        message "@" + po[0] + " " + @workingmin.to_s + "分で" + po[1] + "ポストしちゃってます"
        post message
      end
    end
  end
  
  # マルコフ連鎖 3要素版
  def dbmarcov heading
    st = Time.now().to_i
    text = String.new
    maxlen = rand(60) + 80
    
    # 最初の1語用ランダム生成
    sql = "select * from post_elem where word_index=1;"
    result = Array.new
    begin
      result = @db.execute(sql)
    rescue
      sleep(5)
      retry
    end

    d = rand(result.size)
    
    t1 = result[d][2]
    t2 = result[d][3]
    new_text = heading + t1 + t2
    
    # 続きを生成
    while true
      # 最大文字以上になったらループを抜ける
      break if new_text.size > maxlen

      # 要素1要素2と同じものをSELECTする
      sql = "select * from post_elem where elem1='" + t1 + "' and elem2='" + t2 + "';"
      result = Array.new
      begin
        result = @db.execute(sql)
      rescue
        sleep(5)
        retry
      end

      # なかったらループを抜ける
      break if result.size == 0

      # ランダムで選択
      d = rand(result.size)

      # 連呼避け
      break if (t1==result[d][4]) and (t2==result[d][4])

      # 選択したものをくっつける
      new_text = new_text + result[d][4]
      break if result[d][4] == "EOS"
      t1 = result[d][3]
      t2 = result[d][4]
    end
    post new_text.gsub(/EOS$/,'')

    ed = Time.now().to_i
    @log.info("MARCOV PROC: " + (ed-st).to_s )
    return true
  end


  # bot判定
  def botchk user
    sql = "select bot_name from botlist;"
    bot = Array.new
    begin
      bots = @db.execute(sql)
    rescue
      sleep(5)
      retry
    end

    bots.each do | bot |
      if user == bot[0]
        @log.debug("FUNC: bot match:" + bot[0])
        return true
      end
    end
    return false
  end


  def mecabexclude str
    #a = Kconv.kconv(str,Kconv::UTF8)
    a = str
    a = a.gsub(/\'/, "''")
    a = a.gsub(/\[.*\]/," ")
    a = a.gsub(/(https?|ftp)(:\/\/[-_\.\!\~\*\'\(\)a-zA-Z0-9;\/?:\@\&=+\$,\%\#]+)/," ")
    a = a.gsub(/\n/," ")
    a = a.gsub(/@[A-Za-z0-9_]+/," ")
    a = Kconv.kconv(a,Kconv::UTF8)
    a = a.gsub(/【.*】/," ")
    #a = a.gsub(/（.*）/," ")
    #a = a.gsub(/[「」]/," ")
    #a = a.gsub(/\[.*\]/," ")
    #a = a.gsub(/\(.*\)/," ")
    #a = a.gsub(/[A-Za-z]+/," ")
    #a = a.gsub(/[:\.,\/_\*\"]+/," ")
    return a
  end


  # ポスト
  def post message
    message = Kconv.kconv(message,Kconv::UTF8)
    message = message.gsub(/[\(\[]$/,"")
    message = message.gsub(/[。，、のっで]$/,"")
    message = message.gsub(/よね$/,"")
    message = message.gsub(/です.*/,"")

    begin
      @client.status(:post,message + "ですの")
      #p message
    rescue
      @log.warn(">>send fail: " + message)
      sleep(60)
    end
  end

end


# main
$PROGRAM_NAME = "mirubot-post"

client=Twitter::Client.from_config('/home/miru/bin/mirubot-conf.yaml','bot')
bot=TwitterBot.new client
bot.run
