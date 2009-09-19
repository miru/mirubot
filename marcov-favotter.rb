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
require 'nokogiri'

class TwitterBot
  def initialize client
    @client = client
  end
  
  def run
    @logfile = Logger.new("./fav.txt")
    @logfile.level = Logger::INFO
    @logfile.info("Startup mirubot")
    
    # マルコフ連鎖ポスト
    @logfile.info("Do marcov")
    self.rssmarcov ""
    
  end
  
  def rssmarcov heading
    text = String.new
    text = ""
    
    nokogiri = Nokogiri::HTML.parse(open('http://favotter.matope.com/'))
    descs = nokogiri.xpath('//span[@class=" status_text description"]//text()') 
    descs.each do | desc |
      a = self.mecabexclude Kconv.kconv(desc,Kconv::UTF8)
      text = text+" "+ a
    end

    if text.size == 0
      return
    end

    mecab = MeCab::Tagger.new("-Owakati")
    data = Array.new
    mecab.parse(text + "EOS").split(" ").each_cons(3) do |a|
      data.push h = {'head' => a[0], 'middle' => a[1], 'end' => a[2]}
    end

    maxlen = rand(50) + 50
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
    @logfile.info(new_text.gsub(/EOS$/,''))
    post new_text.gsub(/EOS$/,'')
  end

  def mecabexclude str
    a = str.sub(/^.*: /," ")
    a = a.gsub(/(https?|ftp)(:\/\/[-_\.\!\~\*\'\(\)a-zA-Z0-9;\/?:\@\&=+\$,\%\#]+)/," ")
    a = a.gsub(/＞＜[⌒＞＜←→]/," ")
    a = a.gsub(/【.*】/," ")
    a = a.gsub(/（.*）/," ")
    a = a.gsub(/\[.*\]/," ")
    a = a.gsub(/\(.*\)/," ")
    a = a.gsub(/\n/," ")
    a = a.gsub(/@[A-Za-z0-9_]+/,"")
    a = a.gsub(/[A-Za-z0-9]/,"")
    a = a.gsub(/:,\/_/,"")
    return a
  end

  def post message
    failflg = true
    while failflg
      begin
        @client.status(:post,Kconv.kconv(message,Kconv::UTF8))
      rescue
        @logfile.warn(">>send fail: "+message)
        sleep(1)
      else
        @logfile.debug(">>send message: "+message)
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
