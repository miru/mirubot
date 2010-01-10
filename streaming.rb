#!/usr/bin/env ruby
# coding: utf-8

require 'net/http'
require 'uri'
require 'rubygems'
require 'json'
require "MeCab"
require 'logger'
require 'sqlite3'

$KCODE = "UTF-8"

USERNAME = 'mirubot' # ここを書き換える
PASSWORD = 'x' # ここを書き換える

db=SQLite3::Database.new('mirubot.sqlite3')
db.type_translation = true

uri = URI.parse('http://stream.twitter.com/1/statuses/filter.json')
Net::HTTP.start(uri.host, uri.port) do |http|
  request = Net::HTTP::Post.new(uri.request_uri)
  # Streaming APIはBasic認証のみ
  request.basic_auth(USERNAME, PASSWORD)
  request.set_form_data('follow' => '32789785,4846401,3934431,14202410')
  #request.set_form_data('track' => 'hoge')

  http.request(request) do |response|
    raise 'Response is not chuncked' unless response.chunked?
    response.read_body do |chunk|
      # 空行は無視する = JSON形式でのパースに失敗したら次へ
      status = JSON.parse(chunk) rescue next
      # 削除通知など、'text'パラメータを含まないものは無視して次へ
      next unless status['text']
      user = status['user']
      puts "#{user['screen_name']}: #{status['text']}"
#p status
      sql = "insert into posts values(#{status['id']}, \'#{user['screen_name']}\', \'#{status['text']}\' );"
      p sql
      #db.execute(sql)

    end
  end
end

