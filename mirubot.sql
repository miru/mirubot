CREATE TABLE posts (id integer, user text, status_text text);
CREATE INDEX post_index on posts (id);
CREATE TABLE post_elem (id integer, post_id integer, elem1 text, elem2 text, elem3 text);
CREATE INDEX post_elem_index on post_elem (id);
CREATE INDEX post_elem_post_index on post_elem (post_id);
CREATE INDEX post_elem_post_index1 on post_elem (elem1);
CREATE INDEX post_elem_post_index2 on post_elem (elem2);
CREATE TABLE reply_word (id integer, word text);
CREATE INDEX reply_word_index on reply_word (id);
CREATE INDEX reply_word_index2 on reply_word (word);
CREATE TABLE reply_word_list(id integer, parent_id integer, reply_word);
CREATE INDEX reply_word_list_index on reply_word_list (id);
CREATE INDEX reply_word_list_index2 on reply_word_list (parent_id);
CREATE TABLE botlist (id integer, bot_name text);
CREATE INDEX botlist_index on botlist (id);
CREATE INDEX botlist_index2 on botlist (bot_name);


insert into reply_word values(1, 'はーい');
insert into reply_word values(2, 'もふもふ');
insert into reply_word values(3, 'ちゅっちゅ');
insert into reply_word values(4, 'なでなで');
insert into reply_word values(5, 'ぎゅー');
insert into reply_word values(6, 'ぬるぽ');

insert into reply_word_list values(1, 1, ' ヾ（｡＞‿＜｡ ） いいこいいこ');
insert into reply_word_list values(2, 1,  ' うんうん');
insert into reply_word_list values(3, 2,  ' もっふもふにしてやんよー');
insert into reply_word_list values(4, 2,  ' もふもふは幸せですね ＞ω＜');
insert into reply_word_list values(5, 3, ' さんがちゅっちゅしてるー');
insert into reply_word_list values(6, 3,  ' ちゅっちゅっちゅ♪');
insert into reply_word_list values(7, 4, ' ヾ(＞ω＜ ) なでなでー');
insert into reply_word_list values(8, 4, ' ヾ(＞ω＜ ) よしよし');
insert into reply_word_list values(13,4, ' ヾ(＞ω＜ ) ぽむぽむ'); 
insert into reply_word_list values(8, 5,  ' ぎゅーっとぎゅっと');
insert into reply_word_list values(9, 5,  ' ぎゅっとぎゅっとー');
insert into reply_word_list values(10, 6,  ' ｣(･ ω ･｣) ｶﾞｯ');
insert into reply_word_list values(11, 6,  ' ヽ( ・∀・)ﾉ┌┛ガッ');
insert into reply_word_list values(12, 6,  ' ■━⊂(　・∀・) 彡 ガッ');

insert into botlist values(1, 'mirubot');
insert into botlist values(2, 'ha_ma');
insert into botlist values(3, 'wakatter');
insert into botlist values(4, 'ichiyonnana_bot');
insert into botlist values(5, 'ha_ru_ka');

