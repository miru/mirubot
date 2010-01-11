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

    failflg = true
    while failflg
      begin
        timeline=@client.timeline_for(:friends, :count => 100)
      rescue
        @log.warn("Timeline get failed")
        sleep(60)
      else
        failflg = false
      end
    end

    timeline.each do | status |
      @log.debug("GET TL " + status.user.screen_name + ": " + status.text)

      # 重複してたら次
      sql = "select id from posts where id = " + status.id.to_s + ";"
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
      if result.size != 0
        @log.debug("SKIP: " + status.user.screen_name + " dup post")
        next
      end

      # 自分のポストは保存しない
      if status.user.screen_name == "mirubot"
        next
      end

      # 挨拶ははじく
      if status.text =~ /(おはよう|おやす|おつ|おつあり|おかえり|おかあり)/
        next
      end

      # NG
      if status.text =~ /(えろ|せっくす|セックス|姓|夢精|ちんちん|まんこ|おめこ|妊娠|精子)/
        next
      end

      # DBにポストを保存
      sql = "insert into posts values(" + status.id.to_s + ", \'" + status.user.screen_name + "', '" \
             + status.text.gsub(/\'/,"''") + "'," + status.created_at.to_i.to_s + " );"
      failflg = true
      while failflg
        begin
          @db.execute(sql)
        rescue
          @log.info("SQLERR: " + sql )
          sleep(5)
        else
          failflg = false
        end
      end
      @log.debug("STORE: " + status.user.screen_name + ": " + status.text)

      # 特定ユーザだけmecabにかける
      sql = "select user from mecabuser;"
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

    failflg = true
    while failflg
      begin
        timeline=@client.timeline_for(:replies, :count => 100)
      rescue
        @log.warn("Timeline get failed")
        sleep(60)
      else
        failflg = false
      end
    end

    timeline.each do | status |
      # 重複してたら次
      sql = "select id from posts where id = " + status.id.to_s + ";"
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
      if result.size != 0
        next
      end

      # DBにポストを保存
      sql = "insert into posts values(" + status.id.to_s + ", \'" + status.user.screen_name + \
             "\', \'" + status.text + "\'," + status.created_at.to_i.to_s + " );"
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
      @log.info("STORE: " + status.user.screen_name + ": " + status.text)

      # 特定ユーザだけmecabにかける
      sql = "select user from mecabuser;"
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
    text = Kconv.kconv(text,Kconv::UTF8)
    
    mecab = MeCab::Tagger.new("-Owakati")
    data = Array.new
    mecab.parse(text + "EOS").split(" ").each_cons(3) do | a |

      a[0] = Kconv.kconv(a[0],Kconv::UTF8)
      a[1] = Kconv.kconv(a[0],Kconv::UTF8)
      a[2] = Kconv.kconv(a[0],Kconv::UTF8)

      if a[0] =~ /^[ー。、ｗ！]/
        next
      end

      if a[0]=="ます"
        next
      end
      if a[0]=="を"
        next
      end
      if a[0]=="☆" and ( a[1]=="彡" or  a[1]=="ﾐ" )
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
      sql = "insert into post_elem values(" + maxid.to_s + ", " + status.id.to_s + ", '" \
             + a[0] + "', '" + a[1] + "', '" + a[2] + "', " + idx.to_s + ");"
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
    #a = a.gsub(/（.*）/," ")
    #a = a.gsub(/[「」]/," ")
    a = a.gsub(/\[.*\]/," ")
    #a = a.gsub(/\(.*\)/," ")
    a = a.gsub(/\n/," ")
    a = a.gsub(/@[A-Za-z0-9_]+/," ")
    a = a.gsub(/[A-Za-z]+/," ")
    #a = a.gsub(/[:\.,\/_\*\"]+/," ")
    a = a.gsub(/ですね、わかります/," ")
    a = a.gsub(/第[0-9]+位/," ")
    a = a.gsub(/☆?/," ")
    return a
  end
  
end


# main
client=Twitter::Client.from_config('/home/miru/bin/mirubot-conf.yaml','bot')
bot=TwitterBot.new client
bot.run
