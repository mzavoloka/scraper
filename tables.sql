BEGIN;

CREATE TABLE queries (
    id             serial PRIMARY KEY,
    query          text not null UNIQUE
);

CREATE TABLE search_results (
    id             serial PRIMARY KEY,
    query          integer not null REFERENCES queries ON DELETE CASCADE,
    rank           integer not null,
    url            text not null, 
    title          text not null, 
    description    text not null, 
    added          timestamp not null default now()
);

COMMIT;
