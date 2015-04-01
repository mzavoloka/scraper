BEGIN;

CREATE TABLE queries (
    id             serial PRIMARY KEY,
    query          text not null,
    rank           integer not null,
    url            text not null, 
    title          text not null, 
    description    text not null, 
);

COMMIT;
