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

    @timewait = 60*2       # sec
    @autoposttime = 60*20  # sec
    @workingmin = 30       # min
    @workingth  = 15       # post count

    @botcount = 0
    @doworkingnowflg = false
    @domarcovflg = true

    @lastmarcovdt = Time.now()

    @db=SQLite3::Database.new('mirubot.sqlite3')
    @db.type_translation = true

    sql = "select last from lastpost where name = 'normal';"
    failflg = true
    while failflg
      begin
        result = @db.execute(sql)
      rescue
        sleep(5)
      else
        failflg = false
      end
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
    message = "現在の形態素解析数: " << elem_cnt[0][0].to_s
    post message

    
    # メインループ
    while true
      starttime = Time.now
      doneuser.clear
      
      # タイムラインチェック
      @log.info("Check timeline from DB")
      posts = Array.new()
      sql = "select user,status_text,rowid from posts where rowid > " << @normalid.to_s << " order by dt;"
      @log.debug("SQL: " << sql)
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
      
      posts.each do | po |
        @log.info("TL: " << po[0] << ": " << po[1])

        # 自分は除外
        if po[0] =~ /mirubot/
          next
        end

        # 1回の取得で1ユーザーあたり1回のみ反応
        doneflg = false
        doneuser.each do | u |
          if u == po[0]
            doneflg = true
          end
        end
        if doneflg == true
          @log.info("SKIP: Already replied: " << po[0])
          next
        end
        
        # リプライチェック
        if po[1] =~ /(\@mirubot|みるぼっと)/
          # botはカウントして除外
          if self.botchk po[0]
            @botcount += 1
            @log.info("SENCE BOT: COUNT:" << @botcount.to_s << " -> " << po[0] << ": " << po[1])
            if @botcount > 10
              @botcount = 0
            elsif @botcount > 3
              next
            end
          end

          @log.info("SENSE ID: " << po[0] << ": " << po[1])
          self.dbmarcov "@" << po[0] << " "
          doneuser.push(po[0])
          next
        end
        
        # めかぶキーワードチェック
        self.mecabreply(po[0], po[1])
        
        # 最大ROWIDを保存
        if @normalid < po[2].to_i
          @normalid = po[2].to_i
        end
      end
      
      # 最終チェック時刻あぷでと
      sql = "update lastpost set last = " << @normalid.to_s << " where name = 'normal';"
      @log.debug("SQL: " << sql)
      failflg = true
      while failflg
        begin
          @db.execute(sql)
        rescue
          sleep(5)
        else
          failflg = false
        end
      end
      @log.info("@normalid:" << @normalid.to_s)

      # XX分に1度発動
      if (@lastmarcovdt.to_i + @autoposttime) < Time.now().to_i
        # 仕事してください
        if @doworkingnowflg
          #time = Time.now
          #if (time.hour > 9 && time.hour < 12) || (time.hour > 13 && time.hour < 18)
            @log.info("Do workingnow")
            self.workingnow
          #end
        end
        
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
        @log.info("## sleep " << t.to_s << "sec")
        sleep(t)
      end
    end
  end
  
  
  # めかぶかけて単語に反応
  def mecabreply(user,statustext)
    mecab = MeCab::Tagger.new("-Ochasen")
    a = self.mecabexclude statustext
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
    @log.debug("SQL: " << sql)
    
    while node
      nodefull = node.surface << " " << node.feature
      @log.debug("mecab: "+nodefull)
      
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
          
          @log.info("SQL: " << sql)
          r = rand(result.size)
          message = "@" << user << " " << result[r][0]
          post message
          break
        end
      end
      
      node = node.next
    end
  end

  def workingnow
    countfrom = Time.now().to_i - 60*@workingmin
    @workingth  = 20   # post count
    
    sql = "select user,count(*) from posts where dt > " << countfrom.to_s << " group by user;"
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

    result.each do | po |
      if po[0] > @workingth
        message "@" << po[0] << " " << @workingmin.to_s << "分で" << po[1] << "ポストしちゃってます"
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

    ed = Time.now().to_i
    @log.info("MARCOV PROC: " << (ed-st).to_s )
    return true
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
        @log.debug("FUNC: bot match:" << bot[0])
        return true
      end
    end
    return false
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
    a = a.gsub(/[:\.,\/_\*\"]+/," ")
    return a
  end


  # ポスト
  def post message
    failflg = true
    while failflg
      begin
        @client.status(:post,Kconv.kconv(message << "ですの",Kconv::UTF8))
        #p message
      rescue
        @log.warn(">>send fail: " << message)
        sleep(60)
      else
        @log.info(">>send message: " << message)
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
