#!/usr/bin/ruby

require('rubygems')
gem('twitter4r', '>=0.3.1')
require('twitter')
require 'net/http'
require 'rexml/document';
require 'kconv'
require 'rss'
require "MeCab"
require 'logger'
require 'sqlite3'

class TwitterBot
  def initialize client
    @client = client
    @timewait = 60*3  # sec
    @replyfirst = true

    @db=SQLite3::Database.new('fukkin_counter.sqlite3')
    @db.type_translation = true

  end


  def run
    @logfile = Logger.new("./fukkin_counter.log")
    @logfile.level = Logger::INFO
    @logfile.info("Startup fukkin counter")
    while true
      starttime = Time.now
      
      # タイムラインチェック
      @logfile.info("Do gettimeline")
      
      # ユーザー一覧取得
      failflg = true
      while failflg
        begin
          friends = @client.my(:friends)
        rescue
          @logfile.warn("Friends get faild")
          sleep(60)
        else
          failflg = false
          # ユーザーごとにチェック
          friends.each do | user |
            @logfile.debug("Check user" << user.screen_name)
            self.gettimeline user.screen_name
          end
        end
      end
      
      difftime = Time.now - starttime
      if difftime < @timewait
        t = @timewait - difftime
        @logfile.info("## sleep " << t.to_s)
        sleep(t)
      end
    end
  end
  

  def gettimeline user
    # タイムライン取得
    failflg = true
    while failflg
      begin
        timeline=@client.timeline_for(:user, :id => user)
      rescue
        @logfile.warn("Timeline get failed" & user)
        sleep(60)
      else
        failflg = false
      end
    end
    
    timeline.each do | status |
      if status.text =~ /(腹筋|ふっきん).*(なう|ナウ)/
        @logfile.info("Call fukkin inc for " << user )
        self.fukkin_inc status
      end
    end
    
  end

  def fukkin_inc status
    user = status.user.screen_name
    lastdt = Time.new
    postdt = Time.new

    #p status.created_at.to_i

    # 保存されているユーザのポストの最後のIDを取得
    sql = "select max(last_date) from fukkin where user_name = '" << user << "';"
    @logfile.info("SQL execute: " << sql)
    result = @db.execute(sql)

    if result[0][0] == nil
      # ユーザーをDBに登録
      dt = Time.now.to_i
      lastdate = dt
      sql = "insert into fukkin values('" << user << "', " << dt.to_s << ", 1, 1);"
      result = @db.execute(sql)
      @logfile.info("Create new user: " << user)
      @logfile.info("SQL execute: " << sql)
      message = "@" << user << " さんが腹筋を始めました。頑張って！"
      post message
    else
      # 登録されていれば最後の実行日を取得
      lastdate = result[0][0]

      lastdt = Time.at(lastdate.to_i)
      postdt = status.created_at
      
      # 保存されてる最後のものより新しければDB更新
      if lastdt.yday < postdt.yday
        sql = "select * from fukkin where user_name = '" << user << "';"
        result = @db.execute(sql)
        if (lastdt.yday == (postdt.yday-1)) || ((lastdt.yday==365)&&(postdt.yday==1)) || ((lastdt.yday==366)&&(postdt.yday==1))
          # 日付が連続してる場合はインクリメント
          sql = "update fukkin set last_date=" << postdt.to_i.to_s << ", total_count=" << (result[0][2]+1).to_s << ", continuity_count=" << (result[0][3]+1).to_s << " where user_name='" << user << "';"
          @db.execute(sql)
          sql = "select * from fukkin where user_name = '" << user << "';"
          result = @db.execute(sql)
          message = "@" << user << " さんは、" << (result[0][3]).to_s << "日連続で腹筋しています（カウント合計 " <<  (result[0][2]).to_s << "回）"
          post message
        else
          # 日付が連続じゃない場合は1に戻す
          sql = "update fukkin set last_date=" << postdt.to_i.to_s << ", total_count=" << (result[0][2]+1).to_s << ", continuity_count=1 where user_name='" << user << "';"
          @db.execute(sql)
          sql = "select * from fukkin where user_name = '" << user << "';"
          result = @db.execute(sql)
          message = "@" << user << " さんが、腹筋を再開しました（カウント合計 " <<  (result[0][2]).to_s << "回）"
          post message
        end
      end
    end
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
client=Twitter::Client.from_config('/home/miru/bin/fukkin_counter.yaml','bot')
bot=TwitterBot.new client
bot.run


# EOF
