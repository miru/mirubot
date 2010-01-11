#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'kconv'
require "MeCab"
require 'logger'
require 'sqlite3'

$KCODE = "UTF-8"

db=SQLite3::Database.new('mirubot.sqlite3')
db.type_translation = true

sql = "select id,status_text from posts;"
timeline = db.execute(sql)
    
timeline.each do | status |
  
  sql = "select max(id) from post_elem;"
  result = db.execute(sql)
  maxid = result[0][0].to_i

  text = status[1]
  text = text.sub(/^.*: /," ")
  text = text.gsub(/(https?|ftp)(:\/\/[-_\.\!\~\*\'\(\)a-zA-Z0-9;\/?:\@\&=+\$,\%\#]+)/," ")
  text = text.gsub(/[＞＜⌒＞＜←→]/," ")
  text = text.gsub(/【.*】/," ")
  text = text.gsub(/（.*）/," ")
  text = text.gsub(/[「」]/," ")
  text = text.gsub(/\[.*\]/," ")
  text = text.gsub(/\(.*\)/," ")
  text = text.gsub(/\n/," ")
  text = text.gsub(/@[A-Za-z0-9_]+/," ")
  text = text.gsub(/[A-Za-z]+/," ")
  text = text.gsub(/[:\.,\/_\*\"]+/," ")
  text = text.gsub(/\*lolipop.*中毒/," ")
  
  mecab = MeCab::Tagger.new("-Owakati")
  data = Array.new
  mecab.parse(text + "EOS").split(" ").each_cons(3) do | a |
    maxid += 1
    sql = "insert into post_elem values(" << maxid.to_s << ", " << status[0].to_s << ", '" << a[0] << "', '" << a[1] << "', '" << a[2] << "');"
    db.execute(sql)
    p "SQL: " << sql
  end
end

