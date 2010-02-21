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

class TwitterBot
  def initialize client
    @client = client
    @timewait = 90
    
    @db=SQLite3::Database.new('mirubot.sqlite3')
    @db.type_translation = true

  end
  
  def run
    @log = Logger.new("./mirubot-gettl.log")
    @log.level = Logger::INFO
    @log.info("Startup mirubot logget")

    while true
      starttime = Time.now

      # タイムラインチェック
      @log.info("Do gettimeline")
      self.gettimeline
      # @log.info("Do getmentions")
      # self.getmentions

      difftime = Time.now - starttime
      if difftime < @timewait
        t = @timewait - difftime
        @log.info("## sleep " + t.to_s + "sec")
        sleep(t)
      end
    end
  end


  # 通常タイムライン取得
  def gettimeline
    result = Array.new()

    begin
      timeline=@client.timeline_for(:friends, :count => 200)
    rescue
      @log.warn("Timeline get failed. exit.")
      exit 1
    end

    timeline.each do | status |
      @log.debug("GET TL " + status.user.screen_name + ": " + status.text)

      # 重複してたら次
      sql = "select id from posts where id = " + status.id.to_s + ";"
      begin
        result = @db.execute(sql)
      rescue
        sleep(5)
        retry
      end
      if result.size != 0
        @log.debug("SKIP: " + status.user.screen_name + " dup post")
        next
      end

      # 自分のポストは保存しない
      if status.user.screen_name == "mirubot"
        next
      end

      # 挨拶ははじく
      next if status.text =~ /(おはよう|おやす|おつ|おつあり|おかえり|おかあり)/

      # 今ココもはじく
      next if status.text =~ /((今|いま|イマ|ｲﾏ)(ここ|ココ|ｺｺ|ヘモ|ﾍﾓ)|#imakoko)/
      next if status.text =~ / L:/

      # NG
      next if status.text =~ /(えろ|せっくす|セックス|姓|夢精|チンコ|ちんこ|ちんちん|まんこ|おめこ|妊娠|精子|おっぱい|地震|天気|交通)/


      # DBにポストを保存
      sql = "insert into posts values(" + status.id.to_s + ", \'" + Kconv.kconv(status.user.screen_name,Kconv::UTF8) + "', '" \
             + Kconv.kconv(status.text,Kconv::UTF8).gsub(/\'/,"''") + "'," + status.created_at.to_i.to_s + " );"
      begin
        @db.execute(sql)
      rescue
        @log.error("SQLERR: " + sql )
        sleep(5)
        retry
      end
      @log.info("STORE: " + status.user.screen_name + ": " + status.text)

      # 特定ユーザだけmecabにかける
      sql = "select user from mecabuser;"
      begin
        result = @db.execute(sql)
      rescue
        sleep(5)
        retry
      end
      result.each do | u |
        if status.user.screen_name == u[0]
          self.mecabstore status
          @log.info("MECAB STORE: " + status.user.screen_name + ": " + status.text)
        end
      end
    end

  end

  # mentionsタイムライン取得
  def getmentions
    result = Array.new()

    begin
      timeline=@client.timeline_for(:replies, :count => 100)
    rescue
      @log.warn("Timeline get failed")
      sleep(60)
      retry
    end

    timeline.each do | status |
      # 重複してたら次
      sql = "select id from posts where id = " + status.id.to_s + ";"
      begin
        result = @db.execute(sql)
      rescue
        sleep(5)
        retry
      end

      if result.size != 0
        next
      end

      # DBにポストを保存
      sql = "insert into posts values(" + status.id.to_s + ", \'" + status.user.screen_name + \
             "\', \'" + status.text + "\'," + status.created_at.to_i.to_s + " );"
      begin
        @db.execute(sql)
      rescue
        sleep(5)
        retry
      else
        failflg = false
      end
      @log.info("STORE: " + status.user.screen_name + ": " + status.text)

      # 特定ユーザだけmecabにかける
      sql = "select user from mecabuser;"
      begin
        result = @db.execute(sql)
      rescue
        sleep(5)
        retry
      end
      
      result.each do | u |
        if status.user.screen_name == u[0]
          self.mecabstore status
          @log.info("MECAB STORE: " + status.user.screen_name + ": " + status.text)
        end
      end
    end
  end

  # ポストをmecabにかけて保存
  def mecabstore status
    sql = "select max(id) from post_elem;"
    failflg = true
    idx = 0
    result = Array.new
    begin
      result = @db.execute(sql)
    rescue
      sleep(5)
      retry
    end
    maxid = result[0][0].to_i
    
    text = self.mecabexclude status.text
    #text = Kconv.kconv(text,Kconv::UTF8)
    
    mecab = MeCab::Tagger.new("-Owakati")
    data = Array.new
    mecab.parse(text + "EOS").split(" ").each_cons(3) do | a |

      a[0] = Kconv.kconv(a[0],Kconv::UTF8)
      a[1] = Kconv.kconv(a[0],Kconv::UTF8)
      a[2] = Kconv.kconv(a[0],Kconv::UTF8)

      next if a[0] =~ /^[ー。、ｗ！]/
      next if a[0]=="ます"
      next if a[0]=="を"
      next if a[0]=="☆" and ( a[1]=="彡" or  a[1]=="ﾐ" or a[1]=="ミ" )
      next if (a[0]=="な") and (a[1]=="の") and (a[2]=="よ")
      next if (a[0]=="の") and (a[1]=="よ") and (a[2]=="。")
      next if (a[0]==a[1]) and (a[0]==a[2])

      maxid += 1
      idx += 1
      sql = "insert into post_elem values(" + maxid.to_s + ", " + status.id.to_s + ", '" \
             + a[0] + "', '" + a[1] + "', '" + a[2] + "', " + idx.to_s + ");"
      begin
        @db.execute(sql)
      rescue
        sleep(5)
        retry
      end
      @log.debug("SQL: " + sql )
    end
  end

  # 例外文字
  def mecabexclude str
    a = str.sub(/^.*: /," ")
    a = a.gsub(/(https?|ftp)(:\/\/[-_\.\!\~\*\'\(\)a-zA-Z0-9;\/?:\@\&=+\$,\%\#]+)/," ")
    a = a.gsub(/\'/,"''")
    #a = a.gsub(/[＞＜⌒＞＜←→　]/," ")
    a = a.gsub(/【.*】/," ")
    a = a.gsub(/\[.*\]/," ")
    #a = a.gsub(/\(.*\)/," ")
    a = a.gsub(/\n/," ")
    a = a.gsub(/@[A-Za-z0-9_]+/," ")
    a = a.gsub(/[A-Za-z]+/," ")
    #a = a.gsub(/[:\.,\/_\*\"]+/," ")
    a = a.gsub(/ですね、わかります/," ")
    a = a.gsub(/第[0-9]+位/," ")
    return a
  end
  
end


# main
$PROGRAM_NAME = "mirubot-gettl"

client=Twitter::Client.from_config('/home/miru/bin/mirubot-conf.yaml','bot')
bot=TwitterBot.new client
bot.run
