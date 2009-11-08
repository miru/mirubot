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
    @timewait = 60*10
    
    @db=SQLite3::Database.new('mirubot.sqlite3')
    @db.type_translation = true

  end
  
  def run
    @logfile = Logger.new("./mirubot-gettl.log")
    @logfile.level = Logger::INFO
    @logfile.info("Startup mirubot logget")

    while true
      starttime = Time.now

      # タイムラインチェック
      @logfile.info("Do gettimeline")
      self.gettimeline "miru"
      self.gettimeline "mirupon"
      self.gettimeline "ritsuca"
      self.gettimeline "yamifuu"
      self.gettimeline "myu65"
      self.gettimeline "y_beta"
      self.gettimeline "tetetep"
      self.gettimeline "kynbit"
      self.gettimeline "wakatter"
      self.gettimeline "ha_ma"
      self.gettimeline "ichiyonnana_bot"
      self.gettimeline "nicovideo_tag"
      #self.gettimeline ""

      difftime = Time.now - starttime
      if difftime < @timewait
        t = @timewait - difftime
        @logfile.info("## sleep " << t.to_s << "sec")
        sleep(t)
      end
    end
  end

  # 通常タイムライン取得
  def gettimeline userid
    lastid = 0
    @logfile.info("Get timeline: " << userid)
    
    # 保存されているユーザのポストの最後のIDを取得
    sql = "select max(id) from posts where user = '" << userid << "';"
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

    lastid = result[0][0].to_i
    
    # タイムライン取得
    failflg = true
    while failflg
      begin
        timeline=@client.timeline_for(:user, :id => userid)
      rescue
        @logfile.warn("Timeline " << userid << "get failed")
        sleep(60)
      else
        failflg = false
      end
    end
    
    timeline.each do | status |
      
      if status.id.to_i > lastid
        # SQLite3にデータ保存
        sql="insert into posts values(" << status.id.to_s << ", \'" << status.user.screen_name << "\', \'" << status.text << "\' );"
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
        @logfile.debug("SQL: " << sql )
        
        self.mecabstore status
      end
    end
  end
  
  def mecabstore status
    sql = "select max(id) from post_elem;"
    failflg = true
    idx = 0
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
    maxid = result[0][0].to_i
    
    text = self.mecabexclude status.text
    
    mecab = MeCab::Tagger.new("-Owakati")
    data = Array.new
    mecab.parse(text + "EOS").split(" ").each_cons(3) do | a |

      if a[0] =~ /^[ー。、ｗ！]/
        next
      end

      if a[0]=="ます"
        next
      end
      if a[0]=="を"
        next
      end
      if a[1]=="☆" and a[2]=="彡"
        next
      end
      if (a[0]=="な") && (a[1]=="の") && (a[2]=="よ")
        next
      end
      if (a[0]=="の") && (a[1]=="よ") && (a[2]=="。")
        next
      end

      maxid += 1
      idx += 1
      sql = "insert into post_elem values(" << maxid.to_s << ", " << status.id.to_s << ", '" << a[0] << "', '" << a[1] << "', '" << a[2] << "', " << idx.to_s << ");"
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
      @logfile.debug("SQL: " << sql )
    end
  end
  
  def mecabexclude str
    a = str.sub(/^.*: /," ")
    a = a.gsub(/(https?|ftp)(:\/\/[-_\.\!\~\*\'\(\)a-zA-Z0-9;\/?:\@\&=+\$,\%\#]+)/," ")
    a = a.gsub(/[＞＜⌒＞＜←→　]/," ")
    a = a.gsub(/【.*】/," ")
    a = a.gsub(/（.*）/," ")
    a = a.gsub(/[「」]/," ")
    a = a.gsub(/\[.*\]/," ")
    a = a.gsub(/\(.*\)/," ")
    a = a.gsub(/\n/," ")
    a = a.gsub(/@[A-Za-z0-9_]+/," ")
    a = a.gsub(/[A-Za-z]+/," ")
    a = a.gsub(/[:\.,\/_\*\"]+/," ")
    a = a.gsub(/ですね、わかります/," ")
    #a = a.gsub(/☆彡/," ")
    return a
  end
  
end


# main
client=Twitter::Client.from_config('/home/miru/bin/mirubot-conf.yaml','bot')
bot=TwitterBot.new client
bot.run
