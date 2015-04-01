BEGIN;

CREATE TABLE queries (
    id             serial PRIMARY KEY,
    query          text not null,
);

CREATE TABLE info (
    id             serial PRIMARY KEY,
    query          integer not null REFERENCES query( id ),
    rank           integer not null,
    url            text not null, 
    title          text not null, 
    description    text not null, 
    added          timestamp not null default now()
);

COMMIT;
