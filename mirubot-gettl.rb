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
    
    @db=SQLite3::Database.new('mirupost.sqlite3')
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
      #self.gettimeline "nicovideo_tag"
      #self.gettimeline ""

      difftime = Time.now - starttime
      if difftime < @timewait
        t = @timewait - difftime
        @logfile.info("## sleep " << t.to_s << "sec idle=" << @idlecount.to_s)
        sleep(t)
      end
    end
  end

  # 通常タイムライン取得
  def gettimeline userid
    lastid = 0

    # 保存されているユーザのポストの最後のIDを取得
    sql = "select max(id) from posts where user = '" << userid << "';"
    result = @db.execute(sql)
    result.each do | maxid |
      lastid = maxid[0].to_i
    end

    # タイムライン取得
    failflg = true
    while failflg
      begin
        timeline=@client.timeline_for(:user, :id => userid)
      rescue
        @logfile.warn("Timeline " & userid & "get failed")
        sleep(30)
      else
        failflg = false
      end
    end

    timeline.each do | status |
      
      if status.id > lastid
        # SQLite3にデータ保存
        sql="insert into posts values(" << status.id.to_s << ", \'" << Kconv.kconv(status.user.screen_name,Kconv::UTF8) << "\', \'" << Kconv.kconv(status.text,Kconv::UTF8) << "\' );"
        @db.execute(sql)
        @logfile.info("SQL: " << sql )
      end
    end
  end

end


# main
client=Twitter::Client.from_config('/home/miru/bin/mirubot-conf.yaml','bot')
bot=TwitterBot.new client
bot.run
