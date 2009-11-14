CREATE TABLE posts (id integer, user text, status_text text, dt integer);
CREATE INDEX post_index on posts (id);
CREATE TABLE post_elem (id integer, post_id integer, elem1 text, elem2 text, elem3 text, word_index integer);
CREATE INDEX post_elem_index on post_elem (id);
CREATE INDEX post_elem_post_index on post_elem (post_id);
CREATE INDEX post_elem_post_index1 on post_elem (elem1);
CREATE INDEX post_elem_post_index2 on post_elem (elem2);
CREATE INDEX post_elem_post_index3 on post_elem (word_index);

CREATE TABLE reply_word (id integer, word text);
CREATE INDEX reply_word_index on reply_word (id);
CREATE INDEX reply_word_index2 on reply_word (word);
CREATE TABLE reply_word_list(id integer, parent_id integer, reply_word);
CREATE INDEX reply_word_list_index on reply_word_list (id);
CREATE INDEX reply_word_list_index2 on reply_word_list (parent_id);

CREATE TABLE sence_word (id integer, word text);
CREATE INDEX sence_word_index on sence_word (id);
CREATE INDEX sence_word_index2 on sence_word (word);
CREATE TABLE sence_word_list(id integer, parent_id integer, sence_word_list text);
CREATE INDEX sence_word_list_index on sence_word_list (id);
CREATE INDEX sence_word_list_index2 on sence_word_list (parent_id);

CREATE TABLE botlist (id integer, bot_name text);
CREATE INDEX botlist_index on botlist (id);
CREATE INDEX botlist_index2 on botlist (bot_name);

CREAte TABLE mecabuser (id integer, user text);
CREATE INDEX mecabuser_index on mecabuser(id);

create table lastpost (id integer, name text, last integer);


insert into reply_word values(1, 'はーい');
insert into reply_word values(2, 'もふもふ');
insert into reply_word values(3, 'ちゅっちゅ');
insert into reply_word values(4, 'なでなで');
insert into reply_word values(5, 'ぎゅー');
insert into reply_word values(6, 'ぬるぽ');
insert into reply_word values(7,'(みる|miru|ミル|みるたん)(ぼっと|ボット|bot)');

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
insert into reply_word_list values(13,7,'喚びました？');
insert into reply_word_list values(14,7,'はいはーい');
insert into reply_word_list values(15,7,'｜ω＜）');
insert into reply_word_list values(16,7,'｜彡サッ');


insert into sence_word values(1, '(かわい|可愛|かあい|かーいー)');
insert into sence_word values(2, 'ありがと');
insert into sence_word values(3, 'ぴんぐ');

insert into sence_word_list values(1, 1,  ' ありがとね (〃▽〃)');
insert into sence_word_list values(2, 1,  ' さんも可愛いよ ｡＞ω＜｡');
insert into sence_word_list values(3, 2,  ' どういたしましてっ ＞ω＜');
insert into sence_word_list values(4, 2,  ' お礼なんて… ＞ω＜');
insert into sence_word_list values(5, 3,  ' ぽんぐ');
insert into sence_word_list values(6, 3,  ' ぽーんぽん');

insert into botlist values(1, 'mirubot');
insert into botlist values(2, 'ha_ma');
insert into botlist values(3, 'wakatter');
insert into botlist values(4, 'ichiyonnana_bot');
insert into botlist values(5, 'ha_ru_ka');

insert into mecabuser values(1,"miru");
insert into mecabuser values(2,"mirupon");
insert into mecabuser values(3,"ritsuca");
insert into mecabuser values(4,"yamifuu_");
insert into mecabuser values(5,"myu65");
insert into mecabuser values(6,"y_beta");
insert into mecabuser values(7,"tetetep");
insert into mecabuser values(8,"kynbit");
insert into mecabuser values(9,"nicovideo_tag");
insert into mecabuser values(10,"noripi_BE5D");
insert into mecabuser values(11,"tokkari");
insert into mecabuser values(12,"mrkn");
insert into mecabuser values(13,"toaplus");
insert into mecabuser values(14,"NSXG");
insert into mecabuser values(15,"kozakana");
insert into mecabuser values(16,"dancom");
insert into mecabuser values(17,"Trifecta_beta");
insert into mecabuser values(18,"kazusap");
insert into mecabuser values(19,"hemo57");


insert into lastpost values(1,"normal","0");
insert into lastpost values(2,"reply","0");

