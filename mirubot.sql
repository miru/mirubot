CREATE TABLE posts (id integer, user text, status_text text);
CREATE INDEX post_index on posts (id);
CREATE TABLE post_elem (id integer, post_id integer, elem1 text, elem2 text, elem3 text);
CREATE INDEX post_elem_index on post_elem (id);
CREATE INDEX post_elem_post_index on post_elem (post_id);
