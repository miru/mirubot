#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'net/http'
require 'uri'
require 'json'
#require 'logger'
#require 'sqlite3'
require 'prowl'

USERNAME = 'mirubot'  # ここを書き換える
PASSWORD = 'THogYxav' # ここを書き換える
PRLAPI = "5d06bf5cf4065b6bbab8362c9acb03749b3e7733"

#db=SQLite3::Database.new('mirubot.sqlite3')
#db.type_translation = true

prl = Prowl.new(PRLAPI)

uri = URI.parse('http://stream.twitter.com/1/statuses/filter.json')
Net::HTTP.start(uri.host, uri.port) do |http|
  request = Net::HTTP::Post.new(uri.request_uri)
  # Streaming APIはBasic認証のみ
  request.basic_auth(USERNAME, PASSWORD)
  request.set_form_data('follow' => '32789785,4846401,3934431,14202410,15331996')
  #request.set_form_data('track' => 'hoge')

  http.request(request) do |response|
    raise 'Response is not chuncked' unless response.chunked?
    response.read_body do |chunk|
      # 空行は無視する = JSON形式でのパースに失敗したら次へ
      status = JSON.parse(chunk) rescue next
      # 削除通知など、'text'パラメータを含まないものは無視して次へ
      next unless status['text']

#p status
#p status['user']
      user = status['user']['screen_name']
      text = status['text'].to_s
      puts user + ": " + text
      prl.add(:application => "TwNotify", :event => user, :description => status['text'].to_s)

      #p status
      #sql = "insert into posts values(#{status['id']}, \'#{user['screen_name']}\', \'#{status['text']}\' );"
      #p sql
      #db.execute(sql)

    end
  end
end

